-- =============================================================================
-- ClickHouse · Capa de SERVING (estado actual de baja latencia desde Flink).
-- ReplacingMergeTree(version): Flink hace upsert; CH colapsa duplicados por PK
-- usando la columna de versión (updated_at). FINAL en lectura para estado exacto.
-- Codecs: Delta+ZSTD para enteros/tiempos, LowCardinality para categóricas.
-- =============================================================================
CREATE DATABASE IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.customers_rt
(
    customer_id  Int64 CODEC(Delta, ZSTD(3)),
    email        String CODEC(ZSTD(3)),
    full_name    String CODEC(ZSTD(3)),
    country      LowCardinality(String),
    segment      LowCardinality(String),
    updated_at   DateTime64(6) CODEC(Delta, ZSTD(3))
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY customer_id
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS analytics.orders_rt
(
    order_id      Int64 CODEC(Delta, ZSTD(3)),
    customer_id   Int64 CODEC(Delta, ZSTD(3)),
    status        LowCardinality(String),
    currency      LowCardinality(String),
    total_amount  Decimal(14, 2) CODEC(ZSTD(3)),
    updated_at    DateTime64(6) CODEC(Delta, ZSTD(3))
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(updated_at)
ORDER BY (customer_id, order_id)
SETTINGS index_granularity = 8192;

ALTER TABLE analytics.orders_rt
    ADD INDEX IF NOT EXISTS idx_status status TYPE set(8) GRANULARITY 4;

CREATE TABLE IF NOT EXISTS analytics.order_items_rt
(
    order_item_id Int64 CODEC(Delta, ZSTD(3)),
    order_id      Int64 CODEC(Delta, ZSTD(3)),
    product_id    Int64 CODEC(Delta, ZSTD(3)),
    quantity      Int32 CODEC(T64, ZSTD(3)),
    line_amount   Decimal(14, 2) CODEC(ZSTD(3)),
    _version      DateTime64(3) DEFAULT now64(3) CODEC(Delta, ZSTD(3))
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY (order_id, order_item_id)
SETTINGS index_granularity = 8192;
