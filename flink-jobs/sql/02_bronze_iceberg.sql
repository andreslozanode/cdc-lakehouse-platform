-- =============================================================================
-- 02 · BRONZE (Iceberg, append-only): auditoría inmutable de TODO evento CDC.
-- Se lee el envelope Debezium crudo (avro-confluent) para conservar op/lsn/ts.
-- Particionado oculto por día de ingesta; merge-on-read v2; compresión ZSTD.
-- =============================================================================

-- Fuente cruda (envelope completo) para auditoría
CREATE TABLE IF NOT EXISTS raw_orders_envelope (
  `before` ROW<order_id BIGINT, customer_id BIGINT, status STRING, currency STRING, total_amount DECIMAL(14,2), created_at TIMESTAMP(6), updated_at TIMESTAMP(6)>,
  `after`  ROW<order_id BIGINT, customer_id BIGINT, status STRING, currency STRING, total_amount DECIMAL(14,2), created_at TIMESTAMP(6), updated_at TIMESTAMP(6)>,
  `op`     STRING,
  `ts_ms`  BIGINT,
  `source` ROW<lsn BIGINT, `txId` BIGINT, ts_ms BIGINT, `table` STRING>,
  `ingest_ts` TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL,
  `kafka_offset` BIGINT METADATA FROM 'offset' VIRTUAL,
  `kafka_partition` INT METADATA FROM 'partition' VIRTUAL
) WITH (
  'connector' = 'kafka',
  'topic' = 'oltp.public.orders',
  'properties.bootstrap.servers' = 'kafka:29092',
  'properties.group.id' = 'flink-bronze-orders',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'avro-confluent',
  'avro-confluent.url' = 'http://schema-registry:8081'
);

CREATE TABLE IF NOT EXISTS iceberg.bronze.orders_cdc (
  op            STRING,
  order_id      BIGINT,
  customer_id   BIGINT,
  status        STRING,
  currency      STRING,
  total_amount  DECIMAL(14,2),
  src_lsn       BIGINT,
  src_tx_id     BIGINT,
  event_ts      TIMESTAMP(3),
  ingest_ts     TIMESTAMP_LTZ(3),
  ingest_date   STRING
) PARTITIONED BY (ingest_date) WITH (
  'format-version' = '2',
  'write.format.default' = 'parquet',
  'write.parquet.compression-codec' = 'zstd',
  'write.target-file-size-bytes' = '134217728',
  'write.metadata.delete-after-commit.enabled' = 'true',
  'write.metadata.previous-versions-max' = '10'
);
