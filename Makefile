# =============================================================================
# CDC Streaming Lakehouse — orquestación local
# =============================================================================
SHELL := /bin/bash
COMPOSE := docker compose --env-file .env
.DEFAULT_GOAL := help

.PHONY: help init up up-core up-process up-serving up-bi down clean ps logs \
        register-connectors deploy-flink ddl-clickhouse dbt-run dbt-test \
        smoke lint fmt seed bootstrap

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

init: ## Copia .env.example -> .env si no existe
	@test -f .env || (cp .env.example .env && echo "Creado .env (ajusta los secretos)")

up-core: init ## Levanta origen + ingesta (postgres, kafka, SR, connect, minio, iceberg-rest)
	$(COMPOSE) --profile core up -d

up-process: ## Levanta Flink (jobmanager + taskmanager)
	$(COMPOSE) --profile process up -d --build

up-serving: ## Levanta ClickHouse
	$(COMPOSE) --profile serving up -d

up-bi: ## Levanta Superset + Grafana + Prometheus
	$(COMPOSE) --profile bi up -d --build

up: init ## Levanta TODO el stack
	$(COMPOSE) --profile all up -d --build

down: ## Detiene el stack (conserva volúmenes)
	$(COMPOSE) --profile all down

clean: ## Detiene y BORRA volúmenes (reset total)
	$(COMPOSE) --profile all down -v

ps: ## Estado de los servicios
	$(COMPOSE) ps

logs: ## Sigue logs (uso: make logs S=flink)
	$(COMPOSE) logs -f $(S)

bootstrap: ## Crea tópicos, registra schemas y conectores Debezium
	bash scripts/bootstrap.sh

register-connectors: ## (Re)registra los conectores Debezium
	bash scripts/register-connectors.sh

deploy-flink: ## Despliega los jobs SQL de Flink (CDC -> silver -> sinks)
	bash scripts/deploy-flink-jobs.sh

ddl-clickhouse: ## Aplica el DDL de ClickHouse (idempotente)
	bash scripts/apply-clickhouse-ddl.sh

dbt-run: ## Ejecuta los modelos dbt (gold/marts)
	cd dbt && dbt build --target $${DBT_TARGET:-dev}

dbt-test: ## Ejecuta solo los tests de dbt
	cd dbt && dbt test --target $${DBT_TARGET:-dev}

seed: ## Genera carga transaccional sintética en PostgreSQL
	python scripts/generate_load.py

smoke: ## Healthcheck end-to-end
	bash scripts/healthcheck.sh

lint: ## Lint de SQL (sqlfluff) y Python (ruff)
	sqlfluff lint dbt/models flink-jobs/sql || true
	ruff check scripts ml flink-jobs/python || true

fmt: ## Auto-formato
	sqlfluff fix dbt/models flink-jobs/sql || true
	ruff format scripts ml flink-jobs/python || true
