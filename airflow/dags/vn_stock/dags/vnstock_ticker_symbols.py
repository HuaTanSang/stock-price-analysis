import pendulum
from airflow.decorators import dag 

@dag(
    dag_id="vnstock_get_vn_ticker_symbol",
    schedule=None,
    start_date=pendulum.datetime(2025, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "ticker_symbol", "once"],
)
def vnstock_get_ticker_symbols_in_vietnam_dag(): 
    from vn_stock.tasks.get_vn_ticker_symbol import get_vn_ticker_symbol_and_save_to_minio
    
    get_vn_ticker_symbols_and_save_to_minio = get_vn_ticker_symbol_and_save_to_minio(bucket_name="vn-stock") 
    
    get_vn_ticker_symbols_and_save_to_minio
    
vnstock_get_ticker_symbols_in_vietnam_dag() 
