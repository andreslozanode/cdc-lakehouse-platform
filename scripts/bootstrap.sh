#!/usr/bin/env bash
# Bootstrap end-to-end: espera servicios, registra conectores, aplica DDL,
# despliega jobs Flink. Idempotente.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a

CONNECT="${KAFKA_CONNECT_URL:-http://localhost:8083}"
echo "==> Esperando Kafka Connect ($CONNECT)..."
until curl -fsS "$CONNECT/connectors" >/dev/null 2>&1; do sleep 3; done

echo "==> Registrando conector Debezium..."
bash scripts/register-connectors.sh

echo "==> Aplicando DDL ClickHouse..."
bash scripts/apply-clickhouse-ddl.sh || echo "(ClickHouse no levantado; omite --profile serving)"

echo "==> Desplegando jobs Flink..."
bash scripts/deploy-flink-jobs.sh || echo "(Flink no levantado; omite --profile process)"

echo "==> Bootstrap completo."
