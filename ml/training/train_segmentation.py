"""
Entrena un modelo de segmentación de clientes (KMeans sobre RFM) y lo registra
en MLflow. Lee las features desde ClickHouse (feature_customer_rfm de dbt) o
desde el Parquet de Iceberg (point-in-time). Trazabilidad completa.
"""
from __future__ import annotations

import logging
import os

import clickhouse_connect
import mlflow
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("train-segmentation")

FEATURES = ["recency_days", "frequency", "monetary", "avg_ticket"]


def load_features() -> pd.DataFrame:
    client = clickhouse_connect.get_client(
        host=os.getenv("CLICKHOUSE_HOST", "localhost"),
        port=int(os.getenv("CLICKHOUSE_HTTP_PORT", "8123")),
        username=os.getenv("CLICKHOUSE_USER", "etl"),
        password=os.getenv("CLICKHOUSE_PASSWORD", "change_me_clickhouse"),
        database="ml_features",
    )
    return client.query_df(
        "SELECT customer_id, recency_days, frequency, "
        "toFloat64(monetary) AS monetary, toFloat64(avg_ticket) AS avg_ticket "
        "FROM feature_customer_rfm"
    )


def main() -> None:
    mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "file:./mlruns"))
    mlflow.set_experiment("customer-segmentation")

    df = load_features().dropna()
    if len(df) < 10:
        log.warning("Pocos datos (%d). Genera más carga con scripts/generate_load.py", len(df))

    x = df[FEATURES].to_numpy()
    best = None
    with mlflow.start_run():
        for k in range(3, 7):
            pipe = Pipeline([("scale", StandardScaler()), ("km", KMeans(n_clusters=k, n_init=10, random_state=42))])
            labels = pipe.fit_predict(x)
            score = silhouette_score(x, labels) if len(set(labels)) > 1 else -1.0
            mlflow.log_metric(f"silhouette_k{k}", score)
            log.info("k=%d silhouette=%.4f", k, score)
            if best is None or score > best[1]:
                best = (pipe, score, k)

        pipe, score, k = best
        mlflow.log_params({"algorithm": "kmeans", "k": k, "features": ",".join(FEATURES)})
        mlflow.log_metric("best_silhouette", score)
        mlflow.sklearn.log_model(pipe, name="model", registered_model_name="customer_segmentation")
        log.info("Modelo registrado (k=%d, silhouette=%.4f)", k, score)


if __name__ == "__main__":
    main()
