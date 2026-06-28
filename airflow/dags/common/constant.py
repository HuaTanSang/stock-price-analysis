import os
from dotenv import load_dotenv, find_dotenv

find_dotenv()
load_dotenv()


AIRFLOW_UID = os.get("AIRFLOW_UID")

_AIRFLOW_WWW_USER_USERNAME = os.getenv("_AIRFLOW_WWW_USER_USERNAME")
_AIRFLOW_WWW_USER_PASSWORD = os.getenv("_AIRFLOW_WWW_USER_PASSWORD")
TIMEZONE = "Asia/Ho_Chi_Minh"

MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
AIRFLOW_CONN_MINIO_CONN = os.getenv("AIRFLOW_CONN_MINIO_CONN")

CLICKHOUSE_USER = os.getenv("CLICKHOUSE_USER")
CLICKHOUSE_PASSWORD = os.getenv("CLICKHOUSE_PASSWORD")
CLICKHOUSE_DB = os.getenv("CLICKHOUSE_DB")

# Closed day because of holoday
VIETNAM_HOLIDAYS = {
    # Năm 2026
    "2026-01-01",
    "2026-01-02",
    "2026-02-16",
    "2026-02-17",
    "2026-02-18",
    "2026-02-19",
    "2026-02-20",  # Tết Nguyên Đán
    "2026-04-27",
    "2026-04-30",
    "2026-05-01",
    "2026-08-31",
    "2026-09-01",
    "2026-09-02",
}
