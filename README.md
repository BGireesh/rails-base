# Fleet Billing

Internal Rails service that generates and delivers carrier invoices.

## Stack

| Component  | Version          |
|------------|------------------|
| Ruby       | 3.1              |
| Rails      | 7.0.4            |
| PostgreSQL | 14               |
| Redis      | 7 (Sidekiq)      |
| Node       | 18 (esbuild/sass)|

## Environments

| Environment | Where          | Image                         | `RAILS_ENV`   | Migrations                          |
|-------------|----------------|-------------------------------|---------------|-------------------------------------|
| development | docker compose | `dev` target (built locally)  | `development` | `bin/dev-server` runs `db:prepare`  |
| staging     | GKE            | `runtime` target, built in CI | `production`  | `k8s/migrate-job.yaml` before rollout |
| production  | GKE            | same digest as staging        | `production`  | `k8s/migrate-job.yaml` before rollout |

There is no `staging` Rails environment: staging runs the production image with
staging values injected through environment variables.

The `Dockerfile` has three stages: `build` (compilers, Node, gems, asset
precompile), `dev` (local development only) and `runtime` (the default target,
the only image that is deployed). The runtime image runs as the non-root
`deploy` user, contains no secrets, and has no `ENTRYPOINT`; it starts
`./bin/rails server -b 0.0.0.0` directly and never migrates on boot.

## Development

Requires Docker with Compose v2.

```bash
docker compose up --build
```

- App: http://localhost:3000. Postgres and Redis are also published on
  5432 and 6379.
- `web` builds the `dev` target and bind-mounts the repo, so code changes
  reload without a rebuild. On start, `bin/dev-server` runs `npm install`,
  builds the JS/CSS bundles, runs `db:prepare` (creates, migrates and seeds
  the database), then starts the server. The first boot is slow.
- `worker` runs Sidekiq against the same bind-mounted code. Restart it after
  changing initializers, config or gems: `docker compose restart worker`.
- Credentials in `docker-compose.yml` are local dummy values.

Common commands:

```bash
docker compose logs -f web worker          # follow logs
docker compose exec web bin/rails console  # Rails console
docker compose exec web bin/rails db:migrate
docker compose down                        # stop (keeps the database)
docker compose down -v                     # stop and delete the database volume
```

Changes to `Gemfile`/`Gemfile.lock` need `docker compose up --build`.

Without Docker: `bin/setup` then `bin/rails server` (needs local Ruby 3.1,
Node 18, PostgreSQL and Redis).

### Running the production image locally

```bash
docker build -t fleet-billing:local .
docker run --rm -p 3000:3000 \
  -e SECRET_KEY_BASE=<any value> \
  -e DATABASE_URL=postgres://postgres:postgres@host.docker.internal:5432/fleet_billing_production \
  -e REDIS_URL=redis://host.docker.internal:6379/0 \
  fleet-billing:local
```

The database must already exist and be migrated; run
`./bin/rails db:migrate` with the same image and variables first.

## Runtime configuration (staging and production)

The image is environment-agnostic. Inject these at runtime, from Kubernetes
Secrets for anything sensitive:

| Variable            | Required | Notes                                                         |
|---------------------|----------|---------------------------------------------------------------|
| `SECRET_KEY_BASE`   | yes      | Different per environment                                     |
| `DATABASE_URL`      | yes      | Overrides `config/database.yml`; the path sets the database name |
| `REDIS_URL`         | yes      | Sidekiq                                                       |
| `RAILS_MAX_THREADS` | no       | Puma threads and DB pool size (default 5)                     |
| `PORT`              | no       | Listen port (default 3000)                                    |

`RAILS_ENV=production` and `RAILS_SERVE_STATIC_FILES=true` are set in the
image. `GIT_SHA` is set at build time (`--build-arg GIT_SHA=...`) and reported
by `/healthz` as `revision`.

Web and worker use the same image; the worker overrides the command:
`bundle exec sidekiq -C config/sidekiq.yml`.

## Staging

Each merge to the main branch:

1. **Build once and push by digest**

   ```bash
   docker build --platform linux/amd64 --build-arg GIT_SHA=$GIT_SHA \
     -t REGISTRY/fleet-billing:$GIT_SHA .
   docker push REGISTRY/fleet-billing:$GIT_SHA
   IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' \
     REGISTRY/fleet-billing:$GIT_SHA | cut -d@ -f2 | cut -d: -f2)
   ```

2. **Run migrations** against the staging database with the same digest
   (see [Production migrations](#production-migrations)).

3. **Roll out web and worker** to the new digest, after the migration Job
   succeeds. Deployment manifests are not in this repo; with your deployment
   names:

   ```bash
   kubectl -n staging set image deployment/<web-deployment> \
     <container>=REGISTRY/fleet-billing@sha256:$IMAGE_DIGEST
   kubectl -n staging set image deployment/<worker-deployment> \
     <container>=REGISTRY/fleet-billing@sha256:$IMAGE_DIGEST
   kubectl -n staging rollout status deployment/<web-deployment> --timeout=5m
   ```

4. **Verify**: `/readyz` returns 200 and `/healthz` reports the expected
   `revision`.

## Production

Production is never rebuilt. Promote the digest that passed QA in staging:

1. Run the migration Job in the production namespace with that digest.
2. Roll out web and worker with the same digest, as in staging step 3
   (rolling update, 3 replicas).
3. Verify `/readyz` and the `/healthz` revision.

Roll back by setting the previous digest. Migrations are not rolled back
automatically, so they must stay compatible with the previous release
(expand first, contract in a later release).

## Production migrations

Migrations run as a one-off Kubernetes Job, never on container boot. The Job
runs `./bin/rails db:migrate` with the same image digest as the release and
a DDL-capable database role; web and worker pods use a role without schema
rights.

```bash
export GIT_SHA IMAGE_DIGEST
envsubst < k8s/migrate-job.yaml | kubectl -n <namespace> apply -f -
kubectl -n <namespace> wait --for=condition=complete \
  job/fleet-billing-migrate-$GIT_SHA --timeout=600s \
  || { kubectl -n <namespace> logs job/fleet-billing-migrate-$GIT_SHA; exit 1; }
```

Prerequisites:

- Replace `REGISTRY` in `k8s/migrate-job.yaml` with your registry path.
- A Secret `fleet-billing-migrator` with `DATABASE_URL` (migrator role) and
  `SECRET_KEY_BASE`.
- The database must already exist (created by infra). On a missing database
  the Job fails with `NoDatabaseError`, by design. It uses `db:migrate`, not
  `db:prepare`, so it never creates databases or loads seed data.
- Using the Cloud SQL Auth Proxy: run it as a native sidecar (an
  `initContainer` with `restartPolicy: Always`, GKE 1.29+), or the Job never
  completes.

## Health endpoints

The app listens on port 3000 (or `$PORT`).

- `GET /healthz` — liveness
- `GET /readyz`  — readiness (checks the database connection)

## Background jobs

Sidekiq processes the `default` and `mailers` queues. See `config/sidekiq.yml`.
