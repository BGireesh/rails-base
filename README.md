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

## Local development

```bash
bin/setup
bin/rails server
```

## Docker

```bash
docker compose build
docker compose up
```

The app listens on port 3000. Health endpoints:

- `GET /healthz` — liveness
- `GET /readyz`  — readiness (checks the database connection)

## Background jobs

Sidekiq processes the `default` and `mailers` queues. See `config/sidekiq.yml`.

## Deployment

The image is built in CI and pushed to our internal registry, then rolled out
to Kubernetes (3 replicas, rolling update).
