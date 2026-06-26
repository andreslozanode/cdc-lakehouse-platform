-- =============================================================================
-- 03 · SILVER (Iceberg, upsert v2): estado ACTUAL por clave primaria.
-- El changelog de las fuentes CDC se materializa como tabla upsert (MoR),
-- con deletion vectors / equality-deletes => UPDATE y DELETE correctos.
-- =============================================================================
CREATE TABLE IF NOT EXISTS iceberg.silver.customers (
  customer_id BIGINT,
  email       STRING,
  full_name   STRING,
  country     STRING,
  segment     STRING,
  created_at  TIMESTAMP(6),
  updated_at  TIMESTAMP(6),
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true',
  'write.format.default' = 'parquet',
  'write.parquet.compression-codec' = 'zstd',
  'write.distribution-mode' = 'hash',
  'write.target-file-size-bytes' = '134217728'
);

CREATE TABLE IF NOT EXISTS iceberg.silver.products (
  product_id BIGINT,
  sku        STRING,
  name       STRING,
  category   STRING,
  unit_price DECIMAL(12,2),
  is_active  BOOLEAN,
  created_at TIMESTAMP(6),
  updated_at TIMESTAMP(6),
  PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true',
  'write.format.default' = 'parquet',
  'write.parquet.compression-codec' = 'zstd',
  'write.distribution-mode' = 'hash'
);

CREATE TABLE IF NOT EXISTS iceberg.silver.orders (
  order_id     BIGINT,
  customer_id  BIGINT,
  status       STRING,
  currency     STRING,
  total_amount DECIMAL(14,2),
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6),
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true',
  'write.format.default' = 'parquet',
  'write.parquet.compression-codec' = 'zstd',
  'write.distribution-mode' = 'hash'
);

CREATE TABLE IF NOT EXISTS iceberg.silver.order_items (
  order_item_id BIGINT,
  order_id      BIGINT,
  product_id    BIGINT,
  quantity      INT,
  unit_price    DECIMAL(12,2),
  line_amount   DECIMAL(14,2),
  PRIMARY KEY (order_item_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true',
  'write.format.default' = 'parquet',
  'write.parquet.compression-codec' = 'zstd',
  'write.distribution-mode' = 'hash'
);
