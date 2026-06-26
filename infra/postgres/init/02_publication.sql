-- =============================================================================
-- Publicación + slot lógico. Debezium usa pgoutput (nativo, sin plugins).
-- La tabla de señales habilita snapshots incrementales (read-side, sin lock).
-- =============================================================================
CREATE PUBLICATION dbz_publication FOR TABLE
    customers, products, orders, order_items;

-- Tabla de señales para snapshots incrementales / re-snapshot ad-hoc
CREATE TABLE debezium_signal (
    id    VARCHAR(64) PRIMARY KEY,
    type  VARCHAR(32) NOT NULL,
    data  VARCHAR(2048) NULL
);
GRANT SELECT, INSERT, UPDATE ON debezium_signal TO debezium;
