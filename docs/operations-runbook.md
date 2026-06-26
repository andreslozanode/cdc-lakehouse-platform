# Runbook de operaciones

## Arranque local
```bash
make init        # copia .env, prepara dirs
make up          # levanta todo (perfil all)
make bootstrap   # crea topics/buckets, espera salud
make register-connectors
make deploy-flink
make ddl-clickhouse
make dbt-run
make smoke       # healthcheck E2E
```

## Healthchecks
`scripts/healthcheck.sh` valida 10 servicios (PG, Kafka, SR, Connect, MinIO,
Iceberg REST, Flink JM, ClickHouse, Superset, Grafana). Exit≠0 si algo falla.

## Incidentes comunes

### Lag de consumo crece
1. `GET $FLINK_REST/jobs` → estado del job.
2. Revisar *backpressure* en la UI de Flink (`:8081`).
3. Escalar paralelismo y redeploy con savepoint (`scripts/deploy-flink-jobs.sh`).

### Connector en estado FAILED
```bash
curl -s localhost:8083/connectors/pg-oltp-source/status | jq
# Reiniciar tarea:
curl -X POST localhost:8083/connectors/pg-oltp-source/tasks/0/restart
```
Revisar DLQ `_dlq.pg-oltp-source` para mensajes envenenados.

### Slot de replicación retiene WAL (disco PG creciendo)
```sql
SELECT slot_name, active, pg_size_pretty(
  pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained
FROM pg_replication_slots;
```
Si el slot está inactivo y huérfano: `SELECT pg_drop_replication_slot('<slot>');`.

### ClickHouse: duplicados visibles
Usar `FINAL` o `OPTIMIZE TABLE serving.orders_rt FINAL`. Validar que las MV de
*rollup* no doble-cuentan (idempotencia por PK).

## Mantenimiento Iceberg (programado)
`flink-jobs/sql/99_maintenance.sql`: `rewrite_data_files`, `rewrite_manifests`,
`expire_snapshots` (retención configurable), `remove_orphan_files`.

## Despliegue savepoint-aware
1. Trigger savepoint → `s3a://lakehouse/savepoints`.
2. Build nueva imagen Flink.
3. Resubmit desde el savepoint (cero pérdida de estado).

## Backups
- **PostgreSQL:** `pg_dump` lógico + WAL archiving.
- **Iceberg:** versionado S3 + snapshots (recuperación por *time-travel*).
- **ClickHouse:** `BACKUP TABLE ... TO S3(...)` o reconstrucción desde Silver.
