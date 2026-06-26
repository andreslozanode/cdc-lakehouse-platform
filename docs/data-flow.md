# Flujo de datos (detallado)

## 1. OLTP → Debezium
PostgreSQL escribe en el WAL lógico. La publicación `dbz_publication` expone las tablas
`customers`, `products`, `orders`, `order_items`. Con `REPLICA IDENTITY FULL` el WAL
incluye la imagen previa completa, habilitando `before` en updates/deletes.

El *snapshot inicial* (`snapshot.mode=initial`) carga el estado actual; después se
puede disparar un *incremental snapshot* insertando una señal en `debezium_signal`
sin detener el streaming.

## 2. Debezium → Kafka (Avro)
Cada cambio se publica en `cdc.public.<tabla>` con el envelope:
`{ before, after, source, op, ts_ms }`. El esquema se registra en Schema Registry
(`<topic>-value`, estrategia `TopicNameStrategy`). Errores de (de)serialización van a
la DLQ `_dlq.pg-oltp-source`.

## 3. Kafka → Flink (changelog)
`flink-jobs/sql/01_sources_cdc.sql` declara tablas `src_*` con
`format = 'debezium-avro-confluent'`. Flink interpreta `op` y emite filas de changelog.
El *watermark* y el estado se gestionan por *operator* con TTL de 36h.

## 4. Flink → fan-out (`05_pipeline_dml.sql`, STATEMENT SET)
- **Bronze** (`02_bronze_iceberg.sql`): se proyecta el envelope crudo + metadatos
  (`op`, `ts_ms`, `ingest_date`) a `iceberg.bronze.orders_cdc`, **append-only**,
  particionado por `ingest_date`.
- **Silver** (`03_silver_iceberg.sql`): tablas Iceberg v2 con `write.upsert.enabled`;
  clave primaria por entidad ⇒ estado actual *merge-on-read*.
- **ClickHouse** (`04_sink_clickhouse.sql`): sinks JDBC a `serving.*_rt`
  (ReplacingMergeTree). Deletes se materializan como `is_deleted=1`.

## 5. ClickHouse → Gold (dbt + MV)
- MVs `AggregatingMergeTree` (`revenue_by_day_mv`) pre-agregan en *insert time*.
- dbt construye `marts/core` (`fct_orders`, `dim_customers`) y `marts/ml`
  (`feature_customer_rfm`) con materializaciones incrementales `delete+insert`.

## 6. Consumo
- **Superset:** consulta vistas/marts Gold.
- **Grafana:** Prometheus (Flink/CH/Kafka) + ClickHouse datasource para KPIs.
- **ML:** `ml/feature_pipeline/build_training_set.py` lee Silver con *time-travel*
  (PyIceberg) para *point-in-time correctness*; entrena con MLflow
  (`ml/training/train_segmentation.py`).

## Garantías por tramo
| Tramo | Garantía |
|---|---|
| PG→Debezium | At-least-once con orden por PK (LSN creciente). |
| Kafka | Idempotente + RF/ISR ⇒ sin pérdida. |
| Flink | Exactly-once (checkpoints). |
| Iceberg/CH | Upsert idempotente por PK ⇒ efecto exactly-once observable. |
