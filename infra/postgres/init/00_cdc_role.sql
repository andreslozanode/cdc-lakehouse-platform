-- =============================================================================
-- Rol y permisos de replicación para Debezium (CDC no invasivo vía WAL lógico)
-- =============================================================================
CREATE ROLE debezium WITH REPLICATION LOGIN PASSWORD 'change_me_cdc';

-- Permisos de lectura sobre el esquema de negocio
GRANT CONNECT ON DATABASE oltp TO debezium;
GRANT USAGE ON SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
