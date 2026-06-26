-- =============================================================================
-- 01 · Fuentes CDC: tópicos Debezium (envelope completo) leídos como changelog.
-- format = 'debezium-avro-confluent' => Flink interpreta op=c/u/d/r y produce
-- un stream retractable (+I / -U / +U / -D) sin lógica manual.
-- =============================================================================
CREATE TABLE IF NOT EXISTS src_customers (
  customer_id BIGINT,
  email       STRING,
  full_name   STRING,
  country     STRING,
  segment     STRING,
  created_at  TIMESTAMP(6),
  updated_at  TIMESTAMP(6),
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'oltp.public.customers',
  'properties.bootstrap.servers' = 'kafka:29092',
  'properties.group.id' = 'flink-cdc-customers',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'debezium-avro-confluent',
  'debezium-avro-confluent.url' = 'http://schema-registry:8081'
);

CREATE TABLE IF NOT EXISTS src_products (
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
  'connector' = 'kafka',
  'topic' = 'oltp.public.products',
  'properties.bootstrap.servers' = 'kafka:29092',
  'properties.group.id' = 'flink-cdc-products',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'debezium-avro-confluent',
  'debezium-avro-confluent.url' = 'http://schema-registry:8081'
);

CREATE TABLE IF NOT EXISTS src_orders (
  order_id     BIGINT,
  customer_id  BIGINT,
  status       STRING,
  currency     STRING,
  total_amount DECIMAL(14,2),
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6),
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'oltp.public.orders',
  'properties.bootstrap.servers' = 'kafka:29092',
  'properties.group.id' = 'flink-cdc-orders',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'debezium-avro-confluent',
  'debezium-avro-confluent.url' = 'http://schema-registry:8081'
);

CREATE TABLE IF NOT EXISTS src_order_items (
  order_item_id BIGINT,
  order_id      BIGINT,
  product_id    BIGINT,
  quantity      INT,
  unit_price    DECIMAL(12,2),
  line_amount   DECIMAL(14,2),
  PRIMARY KEY (order_item_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'oltp.public.order_items',
  'properties.bootstrap.servers' = 'kafka:29092',
  'properties.group.id' = 'flink-cdc-order-items',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'debezium-avro-confluent',
  'debezium-avro-confluent.url' = 'http://schema-registry:8081'
);
