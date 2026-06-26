"""
Prueba E2E del pipeline CDC: inserta en PostgreSQL y verifica propagación
hasta ClickHouse (serving) atravesando Debezium -> Kafka -> Flink.

Ejecuta contra el stack de docker-compose ya levantado (`make up`).
    pytest tests/integration/test_e2e_cdc.py -v

Variables de entorno (con defaults para el compose local):
    PG_DSN, CH_HTTP_URL, CH_USER, CH_PASSWORD, E2E_TIMEOUT
"""
from __future__ import annotations

import os
import time
import uuid

import psycopg2
import pytest
import requests

PG_DSN = os.getenv("PG_DSN", "host=localhost port=5432 dbname=shop user=postgres password=change_me_postgres")
CH_HTTP_URL = os.getenv("CH_HTTP_URL", "http://localhost:8123")
CH_USER = os.getenv("CH_USER", "etl")
CH_PASSWORD = os.getenv("CH_PASSWORD", "change_me_clickhouse")
E2E_TIMEOUT = int(os.getenv("E2E_TIMEOUT", "120"))
POLL_INTERVAL = 3


def _ch_query(sql: str) -> str:
    resp = requests.post(
        CH_HTTP_URL,
        params={"query": sql},
        auth=(CH_USER, CH_PASSWORD),
        timeout=10,
    )
    resp.raise_for_status()
    return resp.text.strip()


def _wait_for(predicate, timeout: int, desc: str):
    deadline = time.time() + timeout
    last_exc = None
    while time.time() < deadline:
        try:
            if predicate():
                return True
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
        time.sleep(POLL_INTERVAL)
    pytest.fail(f"Timeout esperando: {desc}. Última excepción: {last_exc}")


@pytest.fixture(scope="module")
def pg_conn():
    conn = psycopg2.connect(PG_DSN)
    conn.autocommit = True
    yield conn
    conn.close()


def test_clickhouse_serving_tables_exist():
    tables = _ch_query("SHOW TABLES FROM serving")
    for expected in ("customers_rt", "orders_rt", "order_items_rt"):
        assert expected in tables, f"Falta tabla serving.{expected}"


def test_insert_propagates_to_clickhouse(pg_conn):
    """Inserta una orden nueva en OLTP y la espera en ClickHouse vía CDC."""
    marker = uuid.uuid4().int % 1_000_000_000
    cur = pg_conn.cursor()
    cur.execute(
        """
        INSERT INTO public.orders (order_id, customer_id, status, order_ts, total_amount, currency, updated_at)
        VALUES (%s, 1, 'created', now(), 199.99, 'USD', now())
        """,
        (marker,),
    )

    def _present() -> bool:
        out = _ch_query(
            f"SELECT count() FROM serving.orders_rt FINAL WHERE order_id = {marker}"
        )
        return out.isdigit() and int(out) >= 1

    _wait_for(_present, E2E_TIMEOUT, f"orden {marker} en serving.orders_rt")

    # Update -> ReplacingMergeTree debe reflejar el último estado con FINAL.
    cur.execute("UPDATE public.orders SET status = 'paid' WHERE order_id = %s", (marker,))

    def _updated() -> bool:
        out = _ch_query(
            f"SELECT status FROM serving.orders_rt FINAL WHERE order_id = {marker}"
        )
        return out == "paid"

    _wait_for(_updated, E2E_TIMEOUT, f"estado 'paid' para orden {marker}")


def test_delete_is_tombstoned(pg_conn):
    """Un DELETE en OLTP debe marcar is_deleted=1 (soft-delete) en serving."""
    marker = uuid.uuid4().int % 1_000_000_000
    cur = pg_conn.cursor()
    cur.execute(
        """
        INSERT INTO public.orders (order_id, customer_id, status, order_ts, total_amount, currency, updated_at)
        VALUES (%s, 1, 'created', now(), 50.00, 'USD', now())
        """,
        (marker,),
    )
    _wait_for(
        lambda: _ch_query(f"SELECT count() FROM serving.orders_rt FINAL WHERE order_id={marker}") == "1",
        E2E_TIMEOUT,
        "insert previo al delete",
    )
    cur.execute("DELETE FROM public.orders WHERE order_id = %s", (marker,))

    def _deleted() -> bool:
        out = _ch_query(
            f"SELECT is_deleted FROM serving.orders_rt FINAL WHERE order_id = {marker}"
        )
        return out == "1"

    _wait_for(_deleted, E2E_TIMEOUT, f"tombstone para orden {marker}")
