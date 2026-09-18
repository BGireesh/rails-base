# syntax=docker/dockerfile:1.7

FROM ruby:3.4-alpine AS builder

# Keep compilers and JavaScript tooling out of the final image.
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    yaml-dev \
    linux-headers \
    libffi-dev \
    nodejs \
    npm \
    tzdata
RUN apk upgrade --no-cache
WORKDIR /app

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

COPY Gemfile Gemfile.lock ./
RUN --mount=type=secret,id=github_token,required=false \
    bundle config set --local deployment true \
 && bundle config set --local without 'development test' \
 && bundle config set --local path /usr/local/bundle \
 && bundle config set --local force_ruby_platform true \
 && if [ -s /run/secrets/github_token ]; then \
      bundle config set --local github.com "x-access-token:$(cat /run/secrets/github_token)"; \
    fi \
 && bundle install --jobs 4 --retry 3 \
 && rm -f .bundle/config

COPY package.json ./
RUN npm install --omit=dev --ignore-scripts

COPY . .
ENV RAILS_ENV=production \
    RACK_ENV=production

RUN SECRET_KEY_BASE=build-only-placeholder \
    npm run build \
 && npm run build:css \
 && bundle exec rake assets:precompile \
 && rm -rf node_modules tmp/cache .bundle

FROM ruby:3.4-alpine AS runner

RUN apk add --no-cache \
    postgresql-client \
    tzdata \
    imagemagick
RUN apk upgrade --no-cache
RUN set -eux; \
    gem fetch resolv -v 0.7.2; \
    gem unpack resolv-0.7.2.gem --target /tmp/resolv; \
    mkdir -p /usr/local/lib/ruby/site_ruby/3.4.0; \
    cp -R /tmp/resolv/resolv-0.7.2/lib/resolv* /usr/local/lib/ruby/site_ruby/3.4.0/; \
    rm -f /usr/local/lib/ruby/gems/3.4.0/specifications/default/resolv-0.7.1.gemspec; \
    rm -rf /tmp/resolv /resolv-0.7.2.gem

# Create dedicated non-root user/group
RUN addgroup -g 10001 -S appgroup \
 && adduser -u 10001 -S appuser -G appgroup

WORKDIR /app

ENV RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=appuser:appgroup /app /app
COPY --chown=appuser:appgroup entrypoint.sh /usr/local/bin/docker-entrypoint

RUN chmod -R go-w /app /usr/local/bundle \
 && chmod 0555 /usr/local/bin/docker-entrypoint \
 && install -d -o appuser -g appgroup -m 0750 /app/tmp/pids /app/log

# Switch to non-root user
USER appuser:appgroup

EXPOSE 3000

# Set entrypoint to run runtime initialization, passing CMD as arguments
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
