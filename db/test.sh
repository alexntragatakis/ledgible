#!/usr/bin/env bash
# Runs the pgTAP suite in db/tests/ via pg_prove inside the postgres container
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose exec -T postgres sh -c \
  'cd /ledgible/tests && pg_prove -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@" [0-9]*.sql' \
  pg_prove "$@"
