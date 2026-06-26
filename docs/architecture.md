# Arquitectura

## Visión general

Pipeline **CDC → Streaming Lakehouse** con separación de capas *hot/cold* y un único
flujo de cambios como fuente de verdad. PostgreSQL emite cambios por replicación
lógica; Debezium los serializa como envelope Avro completo; Flink consume el changelog
y hace *fan-out* a tres destinos con semánticas distintas; ClickHouse sirve OLAP de baja
latencia y dbt construye las marts; Iceberg conserva el histórico para auditoría y ML
reproducible.

![Arquitectura](diagrams/architecture.svg)

## Decisiones de diseño clave

### 1. Envelope completo de Debezium (sin `unwrap` SMT)
El conector **no** aplica `ExtractNewRecordState`. Flink recibe `before`/`after`/`op` y
usa el formato nativo `debezium-avro-confluent`, que traduce el envelope a un *changelog
stream* (`+I`, `-U`, `+U`, `-D`). Esto permite **upserts y deletes reales** aguas abajo
sin lógica manual de interpretación de operaciones.

### 2. Fan-out con tres semánticas
| Destino | Semántica | Motivo |
|---|---|---|
| **Bronze** (Iceberg) | append-only | Auditoría inmutable de cada cambio (incluye `op`, `ts_ms`, LSN). |
| **Silver** (Iceberg v2) | upsert (merge-on-read) | Estado actual reproducible con *time-travel* para ML. |
| **ClickHouse** | ReplacingMergeTree | Serving OLAP; `FINAL`/MV colapsan versiones. |

### 3. Hot/Cold split
- **Hot:** ClickHouse para dashboards y *online features* (latencia ms).
- **Cold:** Iceberg+S3 para histórico ilimitado, *time-travel* y *batch ML* barato.

### 4. Exactly-once de punta a punta
Idempotencia de productor en Kafka + checkpoints exactly-once en Flink + upsert
determinista en Iceberg/ClickHouse ⇒ reprocesos seguros tras fallos o redeploys
(savepoint-aware).

## Capas y componentes

1. **Fuente** — PostgreSQL 16 (`wal_level=logical`, `REPLICA IDENTITY FULL`, publicación
   `dbz_publication`, tabla `debezium_signal` para *incremental snapshots*).
2. **Captura** — Debezium 3.1 (`pgoutput`), heartbeat, DLQ `_dlq.pg-oltp-source`,
   decimales precisos.
3. **Bus** — Kafka 3.8 en KRaft, `zstd`, 12 particiones, *topic auto-create* deshabilitado.
   Schema Registry con compatibilidad `BACKWARD`.
4. **Procesamiento** — Flink 1.20 LTS: catálogo Iceberg REST, *mini-batch* + agregación
   en dos fases, RocksDB con checkpoints incrementales/unaligned, `STATEMENT SET` para
   *fan-out* atómico.
5. **Lakehouse** — Iceberg 1.11 sobre S3/MinIO; *hidden partitioning*, Parquet+ZSTD,
   mantenimiento (compaction, expire snapshots, orphan cleanup).
6. **Serving** — ClickHouse 26.3: ReplacingMergeTree, codecs Delta/T64/ZSTD,
   LowCardinality, async inserts, MVs AggregatingMergeTree para *rollups*.
7. **Transformación** — dbt (staging→intermediate→marts core/ml) con *contracts*,
   `dbt_expectations`, snapshots SCD2 y *exposures*.
8. **Consumo** — Superset (BI), Grafana (observabilidad), ML/AI (PyIceberg + MLflow).

## Escalabilidad

- **Kafka:** particiones por throughput; `min.insync.replicas=2` con RF=3 en MSK.
- **Flink:** paralelismo por *slot*; estado en RocksDB + S3; reescalado vía savepoint.
- **ClickHouse:** sharding + réplicas (`cluster` en dbt prod), `Distributed` engine.
- **Iceberg:** particionado oculto por fecha; compaction asíncrona evita *small files*.
