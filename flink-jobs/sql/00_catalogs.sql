-- =============================================================================
-- 00 · Catálogos: Iceberg (REST sobre S3) — almacenamiento histórico.
-- Se ejecuta primero en cada sesión SQL.
-- =============================================================================
SET 'execution.runtime-mode' = 'streaming';
SET 'pipeline.name' = 'cdc-lakehouse';
SET 'table.local-time-zone' = 'America/Bogota';
SET 'execution.checkpointing.interval' = '30s';

CREATE CATALOG iceberg WITH (
  'type'              = 'iceberg',
  'catalog-type'      = 'rest',
  'uri'               = 'http://iceberg-rest:8181',
  'warehouse'         = 's3://lakehouse/warehouse',
  'io-impl'           = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint'       = 'http://minio:9000',
  's3.path-style-access' = 'true'
);

CREATE DATABASE IF NOT EXISTS iceberg.bronze;
CREATE DATABASE IF NOT EXISTS iceberg.silver;
