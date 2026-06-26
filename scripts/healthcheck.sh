#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a
ok=0; fail=0
check() { printf "  %-22s " "$1"; if eval "$2" >/dev/null 2>&1; then echo "OK"; ok=$((ok+1)); else echo "FAIL"; fail=$((fail+1)); fi; }

echo "== Healthcheck CDC Lakehouse =="
check "PostgreSQL"     "docker compose exec -T postgres pg_isready -U ${POSTGRES_USER:-cdc_admin}"
check "Kafka"          "docker compose exec -T kafka kafka-broker-api-versions --bootstrap-server kafka:29092"
check "Schema Registry" "curl -fsS ${SCHEMA_REGISTRY_URL:-http://localhost:8081}/subjects"
check "Kafka Connect"  "curl -fsS ${KAFKA_CONNECT_URL:-http://localhost:8083}/connectors"
check "MinIO"          "curl -fsS http://localhost:9000/minio/health/live"
check "Iceberg REST"   "curl -fsS http://localhost:8181/v1/config"
check "Flink JM"       "curl -fsS http://localhost:8082/overview"
check "ClickHouse"     "curl -fsS http://localhost:8123/ping"
check "Superset"       "curl -fsS http://localhost:8088/health"
check "Grafana"        "curl -fsS http://localhost:3000/api/health"
echo "== OK=$ok FAIL=$fail =="
[ "$fail" -eq 0 ]
