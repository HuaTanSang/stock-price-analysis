import logging
from typing import Any

from common.utils.minio_helper import get_minio_hook


logger = logging.getLogger(__name__)

def save_data_to_minio(
    data: Any,
    bucket_name: str,
    key: str,
    file_format: str,
    conn_id: str = "minio_conn",
) -> str:
    """
    Save data as a file to MinIO.

    Args:
    - data (Any): Data to save. Can be list[dict], dict, str, bytes, or pandas DataFrame.
    - bucket_name (str): MinIO bucket name.
    - minio_key (str): Object key/path in MinIO.
    - file_format (str): File format. Supported: json, csv, parquet, txt, bytes.
    - conn_id (str): Airflow connection ID for MinIO.

    Returns:
        str: Saved S3 key.
    """

    logger.info(
        "Starting to save file to MinIO. bucket=%s, key=%s, format=%s",
        bucket_name, key, file_format
    )

    try:
        minio_hook = get_minio_hook(minio_conn_id=conn_id)
        logger.info(f"Got MinIO connection sucessfully: {minio_hook}")
        
        if not minio_hook.check_for_bucket(bucket_name=bucket_name): 
            minio_hook.create_bucket(bucket_name=bucket_name)
        
        minio_hook.load_bytes(
            bytes_data=data, 
            key=key, 
            bucket_name=bucket_name, 
        )

        logger.info(
            "Successfully saved file to MinIO. bucket=%s, key=%s",
            bucket_name, key,
        )

        return key

    except Exception as e:
        logger.exception(
            "Failed to save file to MinIO. bucket=%s, key=%s",
            bucket_name, key
        )
        raise RuntimeError(
            f"Failed to save file to MinIO. bucket={bucket_name}, key={key}"
        ) from e