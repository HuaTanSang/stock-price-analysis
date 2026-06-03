import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_gold_price_pipeline",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 6, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "gold_price", "daily"],
)
def vnstock_gold_price_dags(): 
    from vn_stock.tasks.fetch_gold_price import fetch_and_upload_gold_price
    
    run_date_template = "{{ ds }}"

    exchange_rate_task = fetch_and_upload_gold_price(bucket_name="vn_stock", date=run_date_template)

    exchange_rate_task

vnstock_gold_price_dags()
