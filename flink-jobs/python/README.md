# Flink jobs (PyFlink)

Despliegue programático del pipeline CDC. Equivalente al `sql-client` pero
scriptable para CI/CD y con punto de extensión para lógica DataStream
(dead-letter, side-outputs, deduplicación custom por LSN).

```bash
docker compose exec jobmanager \
  python /opt/flink-jobs/python/jobs/cdc_pipeline.py --sql-dir /opt/flink-jobs/sql
```

Despliegue alternativo vía SQL Client (mismo resultado):
```bash
docker compose exec jobmanager bash -lc \
  'cat /opt/flink-jobs/sql/0*.sql | /opt/flink/bin/sql-client.sh'
```
