"""Genera carga transaccional sintética en PostgreSQL para ejercitar el CDC."""
import os
import random
import time

import psycopg2

STATUSES = ["created", "paid", "shipped", "delivered", "cancelled"]


def conn():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=int(os.getenv("POSTGRES_PORT", "5432")),
        dbname=os.getenv("POSTGRES_DB", "oltp"),
        user=os.getenv("POSTGRES_USER", "cdc_admin"),
        password=os.getenv("POSTGRES_PASSWORD", "change_me_postgres"),
    )


def main(n: int = 200):
    c = conn(); c.autocommit = True; cur = c.cursor()
    cur.execute("SELECT customer_id FROM customers")
    customers = [r[0] for r in cur.fetchall()]
    cur.execute("SELECT product_id, unit_price FROM products")
    products = cur.fetchall()
    for i in range(n):
        cid = random.choice(customers)
        cur.execute(
            "INSERT INTO orders (customer_id, status, total_amount) VALUES (%s,%s,0) RETURNING order_id",
            (cid, random.choice(STATUSES)),
        )
        oid = cur.fetchone()[0]
        total = 0
        for _ in range(random.randint(1, 4)):
            pid, price = random.choice(products)
            qty = random.randint(1, 3)
            cur.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (%s,%s,%s,%s)",
                (oid, pid, qty, price),
            )
            total += float(price) * qty
        cur.execute("UPDATE orders SET total_amount=%s, status=%s WHERE order_id=%s",
                    (total, random.choice(STATUSES), oid))
        if i % 50 == 0:
            print(f"  {i} pedidos generados")
        time.sleep(0.01)
    print(f"Listo: {n} pedidos generados.")


if __name__ == "__main__":
    main(int(os.getenv("N", "200")))
