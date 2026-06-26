# =============================================================================
# Imagen Flink con conectores: Kafka, Iceberg (REST+S3), JDBC/ClickHouse, S3
# =============================================================================
ARG FLINK_VERSION=1.20.5
FROM flink:${FLINK_VERSION}-scala_2.12-java17

ARG FLINK_VERSION=1.20.5
ARG ICEBERG_VERSION=1.11.0
ARG FLINK_CONNECTOR_KAFKA=3.3.0-1.20
ARG FLINK_MINOR=1.20

ENV LIB=/opt/flink/lib
WORKDIR ${LIB}

# --- Plugin S3 (presto) para checkpoints y warehouse en S3/MinIO ---
RUN mkdir -p /opt/flink/plugins/s3-fs-presto && \
    cp /opt/flink/opt/flink-s3-fs-presto-${FLINK_VERSION}.jar \
       /opt/flink/plugins/s3-fs-presto/ || true

ADD https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${FLINK_CONNECTOR_KAFKA}/flink-sql-connector-kafka-${FLINK_CONNECTOR_KAFKA}.jar ${LIB}/
ADD https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/${FLINK_VERSION}/flink-sql-avro-confluent-registry-${FLINK_VERSION}.jar ${LIB}/
ADD https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-${FLINK_MINOR}/${ICEBERG_VERSION}/iceberg-flink-runtime-${FLINK_MINOR}-${ICEBERG_VERSION}.jar ${LIB}/
ADD https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar ${LIB}/
ADD https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.2.0-1.19/flink-connector-jdbc-3.2.0-1.19.jar ${LIB}/
ADD https://repo1.maven.org/maven2/com/clickhouse/clickhouse-jdbc/0.7.1/clickhouse-jdbc-0.7.1-all.jar ${LIB}/

# Copia config extra (se fusiona en arranque vía script de entrypoint del Makefile)
COPY conf/ /opt/flink/conf-extra/

RUN chown -R flink:flink ${LIB} /opt/flink/plugins
USER flink
