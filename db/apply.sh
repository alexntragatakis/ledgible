#!/usr/bin/env bash
# Usage:
#   db/apply.sh            apply pending migrations from db/schema/
#   db/apply.sh --status   list applied and pending migrations
#   db/apply.sh --reset    drop the schema and re-apply everything
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

: "${POSTGRES_USER:?}" "${POSTGRES_DB:?}" "${APP_DB_PASSWORD:?APP_DB_PASSWORD must be set in .env}"

psql() {
  docker compose exec -T -e APP_DB_PASSWORD postgres \
    psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
}

case "${1:-}" in
  --reset)
    echo "==> dropping and recreating schema public"
    psql -c 'DROP SCHEMA public CASCADE' -c 'CREATE SCHEMA public'
    ;;
  --status|'') ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

psql -c 'CREATE TABLE IF NOT EXISTS schema_migrations (
           filename   text PRIMARY KEY,
           checksum   text        NOT NULL,
           applied_at timestamptz NOT NULL DEFAULT now()
         )'

applied=0
for path in db/schema/*.sql; do
  filename=$(basename "$path")
  checksum=$(sha256sum < "$path" | cut -d' ' -f1)
  recorded=$(psql -tAc "SELECT checksum FROM schema_migrations WHERE filename = '$filename'")

  if [[ -n "$recorded" ]]; then
    if [[ "$recorded" != "$checksum" ]]; then
      echo "ERROR: $filename was already applied but has since been edited." >&2
      echo "       Add a new numbered migration instead, or rebuild with --reset." >&2
      exit 1
    fi
    [[ "${1:-}" == "--status" ]] && echo "applied  $filename"
    continue
  fi

  if [[ "${1:-}" == "--status" ]]; then
    echo "pending  $filename"
    continue
  fi

  echo "==> applying $filename"
  {
    cat "$path"
    printf "\nINSERT INTO schema_migrations (filename, checksum) VALUES ('%s', '%s');\n" \
      "$filename" "$checksum"
  } | psql -1 -f -
  applied=$((applied + 1))
done

if [[ "${1:-}" != "--status" ]]; then
  echo "==> ${applied} migration(s) applied"
fi
