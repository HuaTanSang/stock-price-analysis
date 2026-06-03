import io 
import json

import pandas as pd
from typing import Any

from airflow.providers.amazon.aws.hooks.s3 import S3Hook


def _serialize_data(data: Any, file_format: str) -> tuple[bytes, str]:
    """
    Convert data to bytes and return content type.
    Args: 
    - data: (any) data that need to be converted to byte
    - file_format: (str) file format of data
    Return: 
    - byte of data
    """

    if file_format == "json":
        body = json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
            default=str,
        ).encode("utf-8")

        return body, "application/json"

    if file_format == "csv":
        buffer = io.StringIO()

        if isinstance(data, pd.DataFrame):
            data.to_csv(buffer, index=False)
        elif isinstance(data, list):
            pd.DataFrame(data).to_csv(buffer, index=False)
        else:
            raise TypeError(
                "CSV format requires pandas DataFrame or list[dict]."
            )

        return buffer.getvalue().encode("utf-8"), "text/csv"

    if file_format == "parquet":
        buffer = io.BytesIO()

        if isinstance(data, pd.DataFrame):
            df = data
        elif isinstance(data, list):
            df = pd.DataFrame(data)
        else:
            raise TypeError(
                "Parquet format requires pandas DataFrame or list[dict]."
            )

        df.to_parquet(buffer, index=False)
        return buffer.getvalue(), "application/octet-stream"

    if file_format == "txt":
        if not isinstance(data, str):
            raise TypeError("TXT format requires str data.")

        return data.encode("utf-8"), "text/plain"

    if file_format == "bytes":
        if not isinstance(data, bytes):
            raise TypeError("bytes format requires bytes data.")

        return data, "application/octet-stream"

    raise ValueError(
        f"Unsupported file format: {file_format}. "
        "Supported formats: json, csv, parquet, txt, bytes."
    )
    

def construct_minio_key(prefix_type: str, file_format: str, date: str | None = None) -> str: 
    """
    Construct minio key for storage
    Args: 
    - prefix_type: (str) type of data that prefix store (exchange_rate, gold_price,...)
    - date: (str) date in format YYYY-MM-DD
    - file_format: (str) format of the file
    Return: 
    - Minio key to object
    """
    if date: 
        parts = date.split("-")
        if len(parts) == 3:
            year, month, day = parts
            return f"{prefix_type}/{year}/{month}/{day}/{prefix_type}-{year}-{month}-{day}.{file_format}"
            
    return f"{prefix_type}/{prefix_type}.{file_format}"

def get_minio_hook(minio_conn_id: str = "minio_conn") -> S3Hook:
    """
    Getting MinIO connection
    Args: 
    - minio_conn_id: (str) id of minio connection
    Returns: 
    - S3Hook
    """
    return S3Hook(aws_conn_id=minio_conn_id)    