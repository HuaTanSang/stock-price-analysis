import logging
from datetime import datetime

import numpy as np
import pandas as pd

from vnstock import Finance
from airflow.decorators import task
from common.save_data_to_minio import save_data_to_minio


logger = logging.getLogger(__name__)

ITEM_ID_MAPPING = {
    # --- INCOME STATEMENT ---
    # Non-bank
    "net_sales": "revenue",
    "sales": "revenue",
    "revenue": "revenue",
    "revenue_1": "revenue",
    "cost_of_sales": "cost_of_good_sold",
    "gross_profit": "gross_profit",
    "selling_expenses": "operation_expense",
    "operating_profit_loss": "operation_profit",
    "interest_expenses": "interest_expense",
    "net_accounting_profit_loss_before_tax": "pre_tax_profit",
    "net_profit_loss_before_tax": "pre_tax_profit",
    "net_profit_loss_after_tax": "post_tax_profit",
    "attributable_to_parent_company": "share_holder_income",
    "net_profit_loss_attributable_to_parent_company": "share_holder_income",
    # Bank
    "net_interest_income": "revenue",
    "interest_and_similar_expenses": "cost_of_good_sold",
    "total_operating_income": "gross_profit",
    "general_and_admin_expenses": "operation_expense",
    "net_operating_profit_before_allowance_for_credit_loss": "operation_profit",
    # --- BALANCE SHEET ---
    # Non-bank
    "short_term_assets": "short_asset",
    "current_assets": "short_asset",
    "cash_and_cash_equivalents": "cash",
    "short_term_financial_investments": "short_invest",
    "short_term_receivables": "short_receivable",
    "inventories": "inventory",
    "long_term_assets": "long_asset",
    "non_current_assets": "long_asset",
    "fixed_assets": "fixed_asset",
    "total_assets": "asset",
    "liabilities": "debt",
    "current_liabilities": "short_debt",
    "long_term_liabilities": "long_debt",
    "non_current_liabilities": "long_debt",
    "owners_equity": "equity",
    "owner_s_equity": "equity",
    "share_capital": "capital",
    "contributed_capital": "capital",
    "undistributed_earnings_after_tax": "un_distributed_income",
    "current_period_undistributed_earnings": "un_distributed_income",
    "retained_earnings": "un_distributed_income",
    "minority_interests": "minor_share_holder_profit",
    "minority_interest": "minor_share_holder_profit",
    "short_term_trade_payables": "payable",
    # Bank
    "cash_and_precious_metals": "cash",
    "balances_with_the_sbv": "short_invest",
    "placements_with_and_loans_to_other_credit_institutions": "short_receivable",
    "total_liabilities": "debt",
    "charter_capital": "capital",
    # --- CASH FLOW ---
    # Non-bank
    "purchases_of_fixed_assets_and_other_long_term_assets": "invest_cost",
    "net_cash_flows_from_investing_activities": "from_invest",
    "net_cash_inflows_outflows_from_investing_activities": "from_invest",
    "net_cash_flows_from_financing_activities": "from_financial",
    "net_cash_inflows_outflows_from_financing_activities": "from_financial",
    "net_cash_flows_from_operating_activities": "from_sale",
    "net_cash_inflows_outflows_from_operating_activities": "from_sale",
    # Bank
    "net_cash_from_operating_activities": "from_sale",
    "net_cash_from_investing_activities": "from_invest",
}

EXPECTED_COLUMNS = {
    "income_statement": [
        "ticker",
        "year",
        "quarter",
        "revenue",
        "year_revenue_growth",
        "quarter_revenue_growth",
        "cost_of_good_sold",
        "gross_profit",
        "operation_expense",
        "operation_profit",
        "year_operation_profit_growth",
        "quarter_operation_profit_growth",
        "interest_expense",
        "pre_tax_profit",
        "post_tax_profit",
        "share_holder_income",
        "year_share_holder_income_growth",
        "quarter_share_holder_income_growth",
        "ebitda",
    ],
    "balance_sheet": [
        "ticker",
        "year",
        "quarter",
        "short_asset",
        "cash",
        "short_invest",
        "short_receivable",
        "inventory",
        "long_asset",
        "fixed_asset",
        "asset",
        "debt",
        "short_debt",
        "long_debt",
        "equity",
        "capital",
        "un_distributed_income",
        "minor_share_holder_profit",
        "payable",
    ],
    "cash_flow": [
        "ticker",
        "year",
        "quarter",
        "invest_cost",
        "from_invest",
        "from_financial",
        "from_sale",
        "free_cash_flow",
    ],
}


def _transform_df(
    df: pd.DataFrame, report_type: str, ticker_symbol: str
) -> pd.DataFrame:
    """Transform VCI transposed dataframe to legacy TCBS row-based dataframe."""
    # Find all time period columns (e.g. '2026-Q1', '2025', '2025-Q4')
    time_cols = [c for c in df.columns if "-" in c or str(c).isdigit()]

    if not time_cols:
        return df

    if "item_id" not in df.columns:
        return df

    # Map item_id to legacy names
    df["mapped_item"] = df["item_id"].map(ITEM_ID_MAPPING)
    # Keep only mapped rows
    df_filtered = df.dropna(subset=["mapped_item"])

    if df_filtered.empty:
        # If no mapping matched, return empty df with expected columns
        if report_type in EXPECTED_COLUMNS:
            return pd.DataFrame(columns=EXPECTED_COLUMNS[report_type])
        return pd.DataFrame()

    # Melt time columns to rows
    melted = pd.melt(
        df_filtered,
        id_vars=["mapped_item"],
        value_vars=time_cols,
        var_name="period",
        value_name="val",
    )

    # Pivot mapped items to columns
    pivoted = melted.pivot_table(
        index="period", columns="mapped_item", values="val", aggfunc="first"
    ).reset_index()

    # Extract year and quarter
    pivoted["year"] = pivoted["period"].str.extract(r"^(\d{4})")
    pivoted["quarter"] = pivoted["period"].str.extract(r"Q(\d)")
    pivoted["quarter"] = pivoted["quarter"].fillna("0")  # fallback

    pivoted["ticker"] = ticker_symbol

    # Ensure all expected columns exist
    if report_type in EXPECTED_COLUMNS:
        expected = EXPECTED_COLUMNS[report_type]
        for col in expected:
            if col not in pivoted.columns:
                pivoted[col] = np.nan
        pivoted = pivoted[expected]

    # Convert everything to string to match String ClickHouse types
    pivoted = pivoted.fillna("").astype(str)

    return pivoted


def _fetch_and_save_report(
    finance: Finance,
    report_type: str,
    ticker_symbol: str,
    bucket_name: str,
    period: str = "quarter",
) -> None:
    report_fetchers = {
        "income_statement": finance.income_statement,
        "balance_sheet": finance.balance_sheet,
        "cash_flow": finance.cash_flow,
        "ratio": finance.ratio,
    }

    fetcher = report_fetchers.get(report_type)
    if fetcher is None:
        raise ValueError(f"Unknown report_type: {report_type}.")

    try:
        df = fetcher(period=period)
    except Exception as e:
        logger.warning(
            "No %s data available for %s. Reason: %s", report_type, ticker_symbol, e
        )
        return

    if df is None or df.empty:
        logger.warning(
            "Empty %s data for ticker=%s, period=%s", report_type, ticker_symbol, period
        )
        return

    # Transform to old format
    if report_type != "ratio":
        df = _transform_df(df, report_type, ticker_symbol)
    else:
        df["ticker"] = ticker_symbol
        df = df.astype(str)

    if df.empty:
        logger.warning(
            "Transformed df is empty for %s, ticker=%s", report_type, ticker_symbol
        )
        return

    date_str = datetime.now().strftime("%Y-%m-%d")
    year, month, day = date_str.split("-")
    key = (
        f"fundamentals/ticker={ticker_symbol}/report={report_type}"
        f"/{year}/{month}/{day}"
        f"/{report_type}-{ticker_symbol}-{date_str}.parquet"
    )

    try:
        data = df.to_parquet(index=False)
        logger.info("Uploading %s to %s/%s", report_type, bucket_name, key)
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info("Upload complete: %s/%s", bucket_name, key)
    except Exception as e:
        logger.exception("Failed to upload %s", report_type)
        raise RuntimeError(f"Failed to upload {report_type}") from e


@task
def fetch_and_upload_fundamentals(
    bucket_name: str,
    ticker_symbol: str,
    source: str = "VCI",
    period: str = "quarter",
) -> None:
    logger.info(
        "[START] Fetching fundamentals for ticker=%s, source=%s", ticker_symbol, source
    )

    try:
        finance = Finance(symbol=ticker_symbol, source=source)
    except Exception as e:
        logger.exception("Failed to initialize Finance")
        raise RuntimeError("Failed to initialize Finance") from e

    for report_type in ["income_statement", "balance_sheet", "cash_flow", "ratio"]:
        _fetch_and_save_report(
            finance=finance,
            report_type=report_type,
            ticker_symbol=ticker_symbol,
            bucket_name=bucket_name,
            period=period,
        )

    logger.info("[DONE] All fundamentals uploaded for ticker=%s", ticker_symbol)
