#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a
CONNECT="${KAFKA_CONNECT_URL:-http://localhost:8083}"

for f in infra/connect/connectors/*.json; do
  name=$(python3 -c "import json,sys;print(json.load(open('$f'))['name'])")
  echo "==> $name"
  if curl -fsS "$CONNECT/connectors/$name" >/dev/null 2>&1; then
    curl -fsS -X PUT -H 'Content-Type: application/json' \
      --data "$(python3 -c "import json;print(json.dumps(json.load(open('$f'))['config']))")" \
      "$CONNECT/connectors/$name/config" | python3 -m json.tool
  else
    curl -fsS -X POST -H 'Content-Type: application/json' \
      --data @"$f" "$CONNECT/connectors" | python3 -m json.tool
  fi
done
echo "==> Estado:"
curl -fsS "$CONNECT/connectors?expand=status" | python3 -m json.tool
