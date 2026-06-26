#!/usr/bin/env bash
set -euo pipefail
superset db upgrade
superset fab create-admin \
  --username "${SUPERSET_ADMIN_USER}" --firstname Admin --lastname User \
  --email admin@example.com --password "${SUPERSET_ADMIN_PASSWORD}" || true
superset init
# Registra la base de datos ClickHouse de analytics
superset set-database-uri \
  --database-name "clickhouse-analytics" \
  --uri "clickhousedb://etl:change_me_clickhouse@clickhouse:8123/analytics" || true
exec gunicorn --bind 0.0.0.0:8088 --workers 4 --timeout 300 \
  "superset.app:create_app()"
