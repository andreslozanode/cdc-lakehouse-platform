-- Online feature serving: ClickHouse responde features en milisegundos para
-- inferencia en tiempo real. Ejemplo: features de un cliente para scoring.
SELECT
    customer_id,
    recency_days,
    frequency,
    toFloat64(monetary)    AS monetary,
    toFloat64(avg_ticket)  AS avg_ticket,
    rfm_segment
FROM ml_features.feature_customer_rfm
WHERE customer_id = {customer_id:Int64};
