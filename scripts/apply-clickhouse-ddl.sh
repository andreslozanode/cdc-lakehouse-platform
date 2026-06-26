#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a
for f in infra/clickhouse/init/*.sql; do
  echo "==> $f"
  docker compose exec -T clickhouse clickhouse-client \
    --user "${CLICKHOUSE_USER:-etl}" --password "${CLICKHOUSE_PASSWORD:-change_me_clickhouse}" \
    --multiquery < "$f"
done
echo "==> DDL ClickHouse aplicado."
