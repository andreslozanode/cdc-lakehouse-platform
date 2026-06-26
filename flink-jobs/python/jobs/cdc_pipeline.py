"""
Despliegue del pipeline CDC en Flink vía PyFlink.

Carga y ejecuta, en orden y dentro de la MISMA sesión, los ficheros SQL:
  00_catalogs -> 01_sources_cdc -> 02_bronze -> 03_silver -> 04_sink_clickhouse
y finalmente el STATEMENT SET (05_pipeline_dml) como un único job con
checkpoint compartido y semántica exactly-once.

Uso:
    python jobs/cdc_pipeline.py --sql-dir ../sql
"""
from __future__ import annotations

import argparse
import logging
import re
from pathlib import Path

from pyflink.table import EnvironmentSettings, StreamTableEnvironment

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("cdc-pipeline")

# El STATEMENT SET / DML de fan-out se ejecuta al final como job de streaming.
ORDER = [
    "00_catalogs.sql",
    "01_sources_cdc.sql",
    "02_bronze_iceberg.sql",
    "03_silver_iceberg.sql",
    "04_sink_clickhouse.sql",
    "05_pipeline_dml.sql",
]


def split_statements(sql_text: str) -> list[str]:
    """Divide por ';' respetando bloques BEGIN ... END del STATEMENT SET."""
    statements, buffer, in_block = [], [], False
    for raw in sql_text.splitlines():
        line = raw.strip()
        if not line or line.startswith("--"):
            continue
        buffer.append(raw)
        upper = line.upper()
        if re.search(r"\bSTATEMENT SET\b", upper) or upper.endswith("BEGIN"):
            in_block = True
        if in_block:
            if upper == "END;" or upper.endswith("END;"):
                statements.append("\n".join(buffer))
                buffer, in_block = [], False
            continue
        if line.endswith(";"):
            statements.append("\n".join(buffer))
            buffer = []
    if buffer:
        statements.append("\n".join(buffer))
    return [s.strip().rstrip(";") for s in statements if s.strip()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sql-dir", default="/opt/flink-jobs/sql")
    args = parser.parse_args()

    env_settings = EnvironmentSettings.in_streaming_mode()
    t_env = StreamTableEnvironment.create(environment_settings=env_settings)

    sql_dir = Path(args.sql_dir)
    for filename in ORDER:
        path = sql_dir / filename
        log.info("Ejecutando %s", path)
        for stmt in split_statements(path.read_text(encoding="utf-8")):
            head = stmt.splitlines()[0][:80]
            log.info("  -> %s ...", head)
            t_env.execute_sql(stmt)

    log.info("Pipeline CDC desplegado. Job de streaming en ejecución.")


if __name__ == "__main__":
    main()
