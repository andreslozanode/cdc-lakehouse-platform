"""
Construye el dataset de entrenamiento leyendo la capa SILVER de Iceberg con
TIME-TRAVEL (snapshot fijo) => reproducibilidad point-in-time para ML.

Lee silver.orders + silver.customers vía PyIceberg/PyArrow, calcula features
RFM y persiste un Parquet versionado en s3://lakehouse/ml/training_sets/.
"""
from __future__ import annotations

import argparse
import datetime as dt
import logging
import os

import pandas as pd
from pyiceberg.catalog import load_catalog

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("build-training-set")


def get_catalog():
    return load_catalog(
        "lakehouse",
        **{
            "type": "rest",
            "uri": os.getenv("ICEBERG_CATALOG_URI", "http://localhost:8181"),
            "s3.endpoint": os.getenv("S3_ENDPOINT", "http://localhost:9000"),
            "s3.access-key-id": os.getenv("S3_ACCESS_KEY", "minioadmin"),
            "s3.secret-access-key": os.getenv("S3_SECRET_KEY", "change_me_minio"),
            "s3.path-style-access": "true",
        },
    )


def load_table(catalog, name: str, snapshot_id: int | None) -> pd.DataFrame:
    tbl = catalog.load_table(name)
    scan = tbl.scan(snapshot_id=snapshot_id) if snapshot_id else tbl.scan()
    return scan.to_pandas()


def build_features(orders: pd.DataFrame, customers: pd.DataFrame) -> pd.DataFrame:
    paid = orders[orders["status"].isin(["paid", "shipped", "delivered"])].copy()
    paid["order_date"] = pd.to_datetime(paid["updated_at"]).dt.date
    today = dt.date.today()

    rfm = (
        paid.groupby("customer_id")
        .agg(
            last_order=("order_date", "max"),
            frequency=("order_id", "nunique"),
            monetary=("total_amount", "sum"),
            avg_ticket=("total_amount", "mean"),
        )
        .reset_index()
    )
    rfm["recency_days"] = rfm["last_order"].apply(lambda d: (today - d).days)
    df = rfm.merge(
        customers[["customer_id", "country", "segment"]], on="customer_id", how="left"
    )
    return df


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--snapshot-id", type=int, default=None,
                   help="snapshot Iceberg para reproducibilidad point-in-time")
    p.add_argument("--out", default="s3://lakehouse/ml/training_sets/customer_rfm")
    args = p.parse_args()

    cat = get_catalog()
    orders = load_table(cat, "silver.orders", args.snapshot_id)
    customers = load_table(cat, "silver.customers", args.snapshot_id)
    features = build_features(orders, customers)

    stamp = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    target = f"{args.out}/dt={stamp}/features.parquet"
    features.to_parquet(target, index=False,
                        storage_options={
                            "key": os.getenv("S3_ACCESS_KEY", "minioadmin"),
                            "secret": os.getenv("S3_SECRET_KEY", "change_me_minio"),
                            "client_kwargs": {"endpoint_url": os.getenv("S3_ENDPOINT", "http://localhost:9000")},
                        })
    log.info("Training set escrito: %s (%d filas)", target, len(features))


if __name__ == "__main__":
    main()
