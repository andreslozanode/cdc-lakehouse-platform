#!/usr/bin/env bash
# Despliega el pipeline SQL. Si existe job previo, hace savepoint antes (zero-loss).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a

JOB_NAME="cdc-lakehouse-fanout"
echo "==> Buscando job previo '$JOB_NAME'..."
RUNNING=$(docker compose exec -T jobmanager /opt/flink/bin/flink list 2>/dev/null | grep "$JOB_NAME" | awk '{print $4}' || true)
if [ -n "${RUNNING:-}" ]; then
  echo "==> Savepoint + stop del job $RUNNING"
  docker compose exec -T jobmanager /opt/flink/bin/flink stop \
    --savepointPath "${FLINK_SAVEPOINT_DIR:-s3a://lakehouse/flink/savepoints}" "$RUNNING" || true
fi

echo "==> Desplegando pipeline (PyFlink)..."
docker compose exec -T jobmanager \
  python /opt/flink-jobs/python/jobs/cdc_pipeline.py --sql-dir /opt/flink-jobs/sql

echo "==> Jobs Flink activos:"
docker compose exec -T jobmanager /opt/flink/bin/flink list
