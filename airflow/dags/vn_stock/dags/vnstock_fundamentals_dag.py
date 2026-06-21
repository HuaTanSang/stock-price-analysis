import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_fundamentals_pipeline_quarterly",
    schedule="0 6 1 1,4,7,10 *",  # 6AM on 1st day of Jan, Apr, Jul, Oct
    start_date=pendulum.datetime(2025, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "fundamentals", "quarterly"],
)
def vnstock_fundamentals_dag():
    from vn_stock.tasks.fetch_fundamentals import fetch_and_upload_fundamentals
    from vn_stock.tasks.fetch_stock_price import get_frequent_tickers_from_minio

    ticker_list = get_frequent_tickers_from_minio()

    fetch_and_upload_fundamentals.partial(
        bucket_name="vn-stock",
        source="VCI",
        period="quarter",
    ).expand(ticker_symbol=ticker_list)


vnstock_fundamentals_dag()
