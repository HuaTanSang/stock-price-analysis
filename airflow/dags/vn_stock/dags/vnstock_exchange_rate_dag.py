import pendulum
from airflow.decorators import dag

@dag(
    dag_id="vnstock_fetch_exchange_rate_pipeline",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "exchange_rate"],
)
def vnstock_exchange_rate_dag():
    from vn_stock.tasks.fetch_exchange_rate import fetch_exchange_rate
    from airflow.dags.common.save_data_to_minio import save_data_to_minio
    from common.utils.minio_helper import construct_minio_key

    run_date_template = "{{ ds }}"
    minio_key = construct_minio_key(run_date_template)

    exchange_rate_task = fetch_exchange_rate(run_date_template)

    save_exchange_rate_task = save_data_to_minio(
        data=exchange_rate_task,
        bucket_name="vnstock",
        s3_key=minio_key,
        file_format="csv",
    )

    exchange_rate_task >> save_exchange_rate_task


vnstock_exchange_rate_dag()