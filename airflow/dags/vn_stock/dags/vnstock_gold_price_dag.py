import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_gold_price_pipeline",
    schedule="0 15 * * *",
    start_date=pendulum.datetime(2026, 1, 6, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "gold_price", "daily"],
)
def vnstock_gold_price_dags():
    from common.startup_dag import start_up_dag
    from common.end_dag import end_dag
    from vn_stock.tasks.fetch_gold_price import fetch_and_upload_gold_price

    run_date_template = "{{ ds }}"

    start_up = start_up_dag()
    fetch_and_upload_gold_price = fetch_and_upload_gold_price(
        bucket_name="vn-stock", date=run_date_template
    )
    end = end_dag()

    start_up >> fetch_and_upload_gold_price >> end


vnstock_gold_price_dags()
