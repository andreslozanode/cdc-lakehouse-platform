# Schema Registry — contratos Avro

Estos `.avsc` documentan los **contratos de los topics CDC** producidos por Debezium
y consumidos por Flink mediante el formato `debezium-avro-confluent`.

## Política de compatibilidad

Compatibilidad por defecto del Registry: **BACKWARD** (configurada en `docker-compose.yml`
vía `SCHEMA_REGISTRY_SCHEMA_COMPATIBILITY_LEVEL: backward`).

| Cambio | ¿Permitido en BACKWARD? |
|---|---|
| Agregar campo opcional (con `default`) | ✅ |
| Eliminar campo opcional | ✅ |
| Agregar campo obligatorio (sin `default`) | ❌ |
| Renombrar campo | ❌ (usar alias) |
| Cambiar tipo incompatible | ❌ |

## Convención de subjects

`TopicNameStrategy`: el subject del valor es `<topic>-value`, p.ej.
`cdc.public.orders-value`. Debezium registra el esquema automáticamente al primer
mensaje; estos archivos sirven como **fuente de verdad versionada** y para validación
en CI (`scripts/validate-schemas.sh`, opcional).

## Registro / validación manual

```bash
# Comprobar compatibilidad antes de mergear
curl -s -X POST http://localhost:8081/compatibility/subjects/cdc.public.orders-value/versions/latest \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @<(jq -Rs '{schema: .}' infra/schema-registry/schemas/order.envelope-value.avsc)
```
