#!/bin/sh
set -e

rm -f /app/tmp/pids/server.pid

# Optional: wait for PostgreSQL when a host is configured.
if [ -n "${POSTGRES_HOST:-}" ]; then
  pg_isready -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-postgres}" -t 30
fi

# Execute the container's main process (passed as CMD)
exec "$@"
