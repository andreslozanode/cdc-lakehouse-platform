-- =============================================================================
-- 05 · PIPELINE (STATEMENT SET): un único job con checkpoint compartido.
-- Bifurca el changelog CDC hacia: Bronze (audit), Silver (estado), ClickHouse.
-- Ejecutar tras 00..04 dentro de la MISMA sesión SQL.
-- =============================================================================
SET 'pipeline.name' = 'cdc-lakehouse-fanout';

EXECUTE STATEMENT SET
BEGIN
  -- (1) BRONZE — auditoría append-only de cada cambio en orders
  INSERT INTO iceberg.bronze.orders_cdc
  SELECT
    op,
    COALESCE(`after`.order_id, `before`.order_id)          AS order_id,
    COALESCE(`after`.customer_id, `before`.customer_id)    AS customer_id,
    COALESCE(`after`.status, `before`.status)              AS status,
    COALESCE(`after`.currency, `before`.currency)          AS currency,
    COALESCE(`after`.total_amount, `before`.total_amount)  AS total_amount,
    `source`.lsn                                            AS src_lsn,
    `source`.`txId`                                         AS src_tx_id,
    TO_TIMESTAMP_LTZ(ts_ms, 3)                              AS event_ts,
    ingest_ts,
    DATE_FORMAT(ingest_ts, 'yyyy-MM-dd')                   AS ingest_date
  FROM raw_orders_envelope;

  -- (2) SILVER — estado actual (upsert) en Iceberg
  INSERT INTO iceberg.silver.customers   SELECT * FROM src_customers;
  INSERT INTO iceberg.silver.products    SELECT * FROM src_products;
  INSERT INTO iceberg.silver.orders      SELECT * FROM src_orders;
  INSERT INTO iceberg.silver.order_items SELECT * FROM src_order_items;

  -- (3) SERVING — ClickHouse (estado actual de baja latencia)
  INSERT INTO ch_customers
    SELECT customer_id, email, full_name, country, segment, updated_at FROM src_customers;
  INSERT INTO ch_orders
    SELECT order_id, customer_id, status, currency, total_amount, updated_at FROM src_orders;
  INSERT INTO ch_order_items
    SELECT order_item_id, order_id, product_id, quantity, line_amount FROM src_order_items;
END;
