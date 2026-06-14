import logging
from datetime import datetime

from common.utils.minio_helper import construct_minio_key
from common.save_data_to_minio import save_data_to_minio

from vnstock import Retail
from airflow.decorators import task


logger = logging.getLogger(__name__)


@task
def fetch_and_upload_gold_price(
    bucket_name: str, date: str | None, source: str = "SJC"
) -> None:
    """
    Fetch gold price data using vnstock API.

    Args:
        source (str | None): Data source. Default is SJC. Can be "btmc".
        date (str | None): Date in YYYY-MM-DD format. Default is current date.

    Returns:
        Gold price data returned by vnstock, including:
        - time: updated time
        - buy: buy price
        - sell: sell price
        - type: type of gold

    Raises:
        RuntimeError: If fetching gold price data fails.
    """
    logger.info(
        "[START] Starting to fetch and upload exchange rate data from vnstock..."
    )

    try:
        retail = Retail()
        gold_price_df = retail.gold(source, date)

        logger.info(f"Fetching data from {source} successfully!")

        data = gold_price_df.to_parquet()

        date = date or datetime.now().strftime("%Y-%m-%d")
        key = construct_minio_key(
            prefix_type="gold_price", date=date, file_format="parquet"
        )

        logger.info(f"Starting to upload data to {bucket_name}")
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )

        logger.info(f"Uploaded successfully at {bucket_name}/{key}")

        return {"bucket_name": bucket_name, "key": key, "status": "success"}

    except Exception as e:
        logger.exception(
            "Error while fetching or uploading gold price. source=%s, date=%s",
            source,
            date,
        )
        raise RuntimeError(
            f"Failed to fetch/upload gold price. source={source}, date={date}"
        ) from e
