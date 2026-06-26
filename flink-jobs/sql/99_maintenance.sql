-- =============================================================================
-- 99 · Mantenimiento de tablas Iceberg (ejecutar en batch/cron, no streaming).
-- Compactación, expiración de snapshots y limpieza de orphan files.
-- =============================================================================
SET 'execution.runtime-mode' = 'batch';

-- Compacta ficheros pequeños del estado actual (silver)
CALL iceberg.system.rewrite_data_files(
  table => 'silver.orders',
  options => map('target-file-size-bytes','134217728','min-input-files','5')
);

-- Reescribe manifiestos (acelera planificación de queries)
CALL iceberg.system.rewrite_manifests('silver.orders');

-- Expira snapshots antiguos (>7 días) y libera metadatos
CALL iceberg.system.expire_snapshots(
  table => 'silver.orders',
  older_than => TIMESTAMP '2026-06-19 00:00:00',
  retain_last => 10
);

-- Borra ficheros huérfanos no referenciados (>3 días)
CALL iceberg.system.remove_orphan_files(
  table => 'silver.orders',
  older_than => TIMESTAMP '2026-06-23 00:00:00'
);
