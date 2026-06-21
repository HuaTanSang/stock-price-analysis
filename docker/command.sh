# For Airflow
docker compose --env-file ../.env -f docker-compose.airflow.yaml up -d --build
docker compose --env-file ../.env -f docker-compose.airflow.yaml down

# For Minio
docker compose --env-file ../.env -f docker-compose.minio.yaml up -d
docker compose --env-file ../.env -f docker-compose.minio.yaml down

# For ClickHouse
docker compose --env-file ../.env -f docker-compose.clickhouse.yaml up -d
docker compose --env-file ../.env -f docker-compose.clickhouse.yaml down

# For dbt
docker compose -f docker-compose.dbt.yaml up -d
docker compose -f docker-compose.dbt.yaml down


# For superset 
docker compose -f docker-compose.superset.yaml up -d --build 
docker compose -f docker-compose.superset.yaml down -v 

# For Grafana 
docker compose -f docker-compose.grafana.yaml up -d --build 
docker compose -f docker-compose.grafana.yaml down -v 
