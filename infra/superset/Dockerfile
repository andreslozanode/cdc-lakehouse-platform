ARG SUPERSET_VERSION=4.1.1
FROM apache/superset:${SUPERSET_VERSION}

USER root
# Driver ClickHouse para Superset
RUN pip install --no-cache-dir clickhouse-connect==0.8.14 psycopg2-binary==2.9.10
COPY superset_config.py /app/pythonpath/superset_config.py
COPY bootstrap.sh /app/bootstrap.sh
RUN chmod +x /app/bootstrap.sh
USER superset
ENTRYPOINT ["/app/bootstrap.sh"]
