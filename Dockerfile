# syntax=docker/dockerfile:1

# Fleet Billing - Rails application image
# Multi-stage build: gems + assets are compiled in a throwaway build stage;
# the final image is a slim, non-root, secret-free runtime.
#
# Targets:
#   runtime (default/last stage) - the deployable image. CI builds THIS once
#   and promotes the same digest: staging (QA) -> production. Both are GKE;
#   the image is environment-agnostic - only injected env vars differ.
#   dev - used ONLY by docker compose for local laptop development
#   (`target: dev` in docker-compose.yml). Full bundle incl. dev/test gems,
#   Node available, RAILS_ENV=development, repo bind-mounted for hot reload.
# Maintainer: platform@example.com

#################################################################
# Stage 1: build - compiles gems, bundles JS/CSS, precompiles assets.
# Everything here (compilers, Node, npm caches) stays OUT of the final image.
#################################################################
FROM ruby:3.1 AS build

ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    BUNDLE_APP_CONFIG=/usr/local/bundle

# Node 18 for the asset pipeline.
# NOTE: the old Dockerfile pulled Node via NodeSource's setup_18.x script,
# which broke when Node 18 went EOL and NodeSource dropped the package.
# We now copy the official Node 18 binaries instead - and only into this
# build stage, so Node never ships in the runtime image.
COPY --from=node:18-bookworm /usr/local/bin/ /usr/local/bin/
COPY --from=node:18-bookworm /usr/local/lib/node_modules/ /usr/local/lib/node_modules/
# yarn is required because jsbundling-rails / cssbundling-rails rake tasks
# shell out to `yarn build` / `yarn build:css` during assets:precompile.
# The official node image ships yarn 1.x under /opt (bin/yarn is a symlink).
COPY --from=node:18-bookworm /opt/yarn-v1.22.22/ /opt/yarn-v1.22.22/

# Build-only system packages (compiler toolchain for native gems, curl for
# downloads). Removed from the final image by virtue of multi-stage.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN node -v && yarn -v

WORKDIR /app

# --- gems: production only, resolved from the committed lockfile ----------
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true \
    && bundle config set --local without "development test" \
    && bundle config set --local path /usr/local/bundle \
    && bundle install --jobs "$(nproc)" \
    && rm -rf /usr/local/bundle/cache

# --- JS dependencies + asset bundles ---------------------------------------
# NOTE: package.json has no lockfile; dependency versions are pinned exactly.
# TODO: commit a package-lock.json and switch to `npm ci` for reproducibility.
COPY package.json ./
RUN npm install --omit=dev \
    && npm cache clean --force
COPY app/javascript ./app/javascript
COPY app/assets ./app/assets
RUN npm run build && npm run build:css

# --- full app + asset precompile -------------------------------------------
COPY . .
# Dummy key exists only for the duration of this RUN command (asset
# compilation boots Rails); it is never persisted to an image layer.
# node_modules is deleted after precompile. the runtime only needs the
# compiled output in public/assets, not the JS toolchain/dependencies.
RUN SECRET_KEY_BASE=dummy-for-asset-precompile \
    bundle exec rake assets:precompile \
    && rm -rf /app/node_modules

#################################################################
# Stage: dev - local laptop development image, built via docker compose
# (`target: dev`). Inherits the full toolchain from `build` and widens the
# bundle to include development/test gems. NEVER shipped: CI builds the
# default (last) stage, which is `runtime` below.
#################################################################
FROM build AS dev

ENV RAILS_ENV=development \
    RACK_ENV=development

# Widen the production-only bundle from the build stage to include the
# development/test groups (rspec, pry, web-console, rubocop, ...).
RUN bundle config unset --local without \
    && bundle install --jobs "$(nproc)"

# Compose bind-mounts the repo over /app and supplies the full boot command
# `# (npm install + asset builds + db:prepare + rails server), so this stage`
# deliberately has no ENTRYPOINT/CMD - it is only ever run via docker compose.
EXPOSE 3000

#################################################################
# Stage 2 (default): runtime - slim Debian base, only what the app needs.
# This is the image CI builds once and promotes by digest: staging -> prod.
#################################################################
FROM ruby:3.1-slim-bookworm AS runtime

ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_APP_CONFIG=/usr/local/bundle

# Runtime-only libraries: libpq5 for the pg gem, tzdata for time zones.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Unprivileged runtime user - no sudo, no root.
RUN groupadd --system --gid 1000 deploy \
    && useradd --system --uid 1000 --gid deploy --shell /usr/sbin/nologin --create-home deploy

WORKDIR /app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=deploy:deploy /app /app

# Writable dirs for the runtime user (pids, bootsnap cache, logs).
RUN mkdir -p /app/tmp/pids /app/log \
    && chown -R deploy:deploy /app/tmp /app/log

# Traceability: CI passes --build-arg GIT_SHA=$GITHUB_SHA; /healthz already
# surfaces it as "revision", and the OCI label exposes it at the registry.
ARG GIT_SHA=unknown
ENV GIT_SHA=$GIT_SHA
LABEL org.opencontainers.image.revision=$GIT_SHA \
      org.opencontainers.image.source="https://github.com/atob/rails-base" \
      org.opencontainers.image.title="fleet-billing"

USER deploy

EXPOSE 3000

# Secrets (SECRET_KEY_BASE / RAILS_MASTER_KEY / POSTGRES_* / REDIS_URL) are
# injected at runtime via k8s Secrets / external-secrets - never baked into
# the image. Migrations are NOT run on boot: CI runs them as a separate k8s
# Job (same image, RUN_MIGRATIONS=true, elevated DB role) before rollout.
ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]