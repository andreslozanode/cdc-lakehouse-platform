-- =============================================================================
-- ClickHouse · GOLD nativo en tiempo real vía Materialized Views incrementales.
-- AggregatingMergeTree mantiene agregados pre-calculados sin recomputar.
-- (dbt complementa con marts gobernados/testeados; ver carpeta dbt/.)
-- =============================================================================

-- Destino: ingresos diarios por país (estado agregado)
CREATE TABLE IF NOT EXISTS analytics.revenue_by_day
(
    order_date    Date,
    country       LowCardinality(String),
    orders_state  AggregateFunction(uniq, Int64),
    revenue_state AggregateFunction(sum, Decimal(14, 2))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(order_date)
ORDER BY (order_date, country);

-- MV: alimenta revenue_by_day desde el stream de orders_rt
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.revenue_by_day_mv
TO analytics.revenue_by_day AS
SELECT
    toDate(o.updated_at)                 AS order_date,
    c.country                            AS country,
    uniqState(o.order_id)                AS orders_state,
    sumState(o.total_amount)             AS revenue_state
FROM analytics.orders_rt AS o
INNER JOIN analytics.customers_rt AS c USING (customer_id)
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY order_date, country;

-- Vista de lectura amigable (resuelve los -State con -Merge)
CREATE VIEW IF NOT EXISTS analytics.v_revenue_by_day AS
SELECT
    order_date,
    country,
    uniqMerge(orders_state)  AS orders,
    sumMerge(revenue_state)  AS revenue
FROM analytics.revenue_by_day
GROUP BY order_date, country;
