-- =============================================================================
-- 04 · SINK ClickHouse (serving rápido). JDBC con upsert por PK; la dedup final
-- la resuelve el motor ReplacingMergeTree(version) del lado de ClickHouse.
-- =============================================================================
CREATE TABLE IF NOT EXISTS ch_customers (
  customer_id BIGINT,
  email       STRING,
  full_name   STRING,
  country     STRING,
  segment     STRING,
  updated_at  TIMESTAMP(6),
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:clickhouse://clickhouse:8123/analytics',
  'table-name' = 'customers_rt',
  'driver' = 'com.clickhouse.jdbc.ClickHouseDriver',
  'username' = 'etl',
  'password' = 'change_me_clickhouse',
  'sink.buffer-flush.max-rows' = '5000',
  'sink.buffer-flush.interval' = '2s',
  'sink.max-retries' = '3'
);

CREATE TABLE IF NOT EXISTS ch_orders (
  order_id     BIGINT,
  customer_id  BIGINT,
  status       STRING,
  currency     STRING,
  total_amount DECIMAL(14,2),
  updated_at   TIMESTAMP(6),
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:clickhouse://clickhouse:8123/analytics',
  'table-name' = 'orders_rt',
  'driver' = 'com.clickhouse.jdbc.ClickHouseDriver',
  'username' = 'etl',
  'password' = 'change_me_clickhouse',
  'sink.buffer-flush.max-rows' = '5000',
  'sink.buffer-flush.interval' = '2s',
  'sink.max-retries' = '3'
);

CREATE TABLE IF NOT EXISTS ch_order_items (
  order_item_id BIGINT,
  order_id      BIGINT,
  product_id    BIGINT,
  quantity      INT,
  line_amount   DECIMAL(14,2),
  PRIMARY KEY (order_item_id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:clickhouse://clickhouse:8123/analytics',
  'table-name' = 'order_items_rt',
  'driver' = 'com.clickhouse.jdbc.ClickHouseDriver',
  'username' = 'etl',
  'password' = 'change_me_clickhouse',
  'sink.buffer-flush.max-rows' = '5000',
  'sink.buffer-flush.interval' = '2s',
  'sink.max-retries' = '3'
);
