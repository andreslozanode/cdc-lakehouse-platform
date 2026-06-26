# Integración ML / AI y BI / Reporting

El lakehouse está diseñado para servir **dos consumidores analíticos** sin fricción:
modelos (ML/AI) y reporting (BI). La clave es la separación *hot/cold* y los contratos
de datos (dbt + Schema Registry).

## ML / AI

### Reproducibilidad *point-in-time*
Silver en Iceberg expone *time-travel*. `ml/feature_pipeline/build_training_set.py`
lee snapshots concretos con **PyIceberg**, garantizando que un *training set* sea
exactamente reconstruible (sin *label leakage* temporal):

```python
table.scan(snapshot_id=<snap>).to_arrow()   # estado del mundo en T
```

### Offline vs Online features
| Plano | Fuente | Latencia | Uso |
|---|---|---|---|
| **Offline** | Iceberg Silver | minutos/batch | Entrenamiento, backfills. |
| **Online** | ClickHouse `serving.*` + MV | ms | Inferencia/serving (`ml/serving/online_features.sql`). |

Esto evita *training/serving skew*: ambas derivan de la **misma** definición de feature
(p.ej. RFM en `dbt/models/marts/ml/feature_customer_rfm.sql`).

### Pipeline de ejemplo (segmentación)
1. `build_training_set.py` → Parquet a `s3://lakehouse/ml/training_sets/`.
2. `train_segmentation.py` → KMeans sobre RFM, *sweep* k=3..6 por *silhouette*,
   registro de modelo y métricas en **MLflow**.
3. Servir scores como tabla/feature en ClickHouse para consumo *online*.

### Extensión a GenAI / RAG
Bronze/Silver pueden alimentar embeddings; ClickHouse soporta *vector search*
(distancias L2/cosine) para *retrieval* de baja latencia junto a features estructuradas.

## BI / Reporting

### Marts gobernadas
dbt expone `marts/core` (`fct_orders`, `dim_customers`) con **contracts enforced**
(tipos y nullability verificados en `build`) y tests (`dbt_expectations`,
`unique`/`not_null`/relaciones). Las *exposures* documentan qué dashboards dependen de
qué modelos.

### Superset
Conecta vía `clickhouse-connect` a las marts Gold. `bootstrap.sh` registra la base
automáticamente. Recomendado: construir *datasets* sobre vistas `v_*` y MVs de rollup
para latencia sub-segundo.

### Grafana
Observabilidad operativa (Prometheus: throughput Flink, checkpoints, inserts CH) y
KPIs de negocio vía datasource ClickHouse (`revenue_by_day`).

## Contratos y calidad
- **Schema Registry (BACKWARD):** evita romper consumidores ante cambios de esquema.
- **dbt contracts + tests:** frenan regresiones en CI (Slim CI con `state:modified+`).
- **Source freshness:** `dbt source freshness` alerta si el CDC se atrasa.
