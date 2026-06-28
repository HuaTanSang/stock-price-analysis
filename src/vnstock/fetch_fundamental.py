from vnstock import Finance
import logging

logger = logging.getLogger(__name__)


# def _fetch_and_save_report(
#     finance: Finance,
#     report_type: str,
#     ticker_symbol: str,
#     period: str = "quarter",
# ) -> None:
#     report_fetchers = {
#         "income_statement": finance.income_statement,
#         "balance_sheet": finance.balance_sheet,
#         "cash_flow": finance.cash_flow,
#         "ratio": finance.ratio,
#     }

#     fetcher = report_fetchers.get(report_type)
#     if fetcher is None:
#         raise ValueError(f"Unknown report_type: {report_type}.")

#     try:
#         df = fetcher(period=period)
#     except Exception as e:
#         logger.warning(
#             "No %s data available for %s. Reason: %s", report_type, ticker_symbol, e
#         )
#         return

#     if df is None or df.empty:
#         logger.warning(
#             "Empty %s data for ticker=%s, period=%s", report_type, ticker_symbol, period
#         )
#         return

# def fetch_and_upload_fundamentals(
#     ticker_symbol: str,
#     source: str = "VCI",
#     period: str = "quarter",
# ) -> None:
#     logger.info(
#         "[START] Fetching fundamentals for ticker=%s, source=%s", ticker_symbol, source
#     )

#     try:
#         finance = Finance(symbol=ticker_symbol, source=source)
#     except Exception as e:
#         logger.exception("Failed to initialize Finance")
#         raise RuntimeError("Failed to initialize Finance") from e

#     for report_type in ["income_statement", "balance_sheet", "cash_flow", "ratio"]:
#         _fetch_and_save_report(
#             finance=finance,
#             report_type=report_type,
#             ticker_symbol=ticker_symbol,
#             period=period,
#         )

#     logger.info("[DONE] All fundamentals uploaded for ticker=%s", ticker_symbol)


# print(fetch_and_upload_fundamentals(ticker_symbol="VCB"))


finance = Finance(symbol="VCB", source="KBS")

# Mode mặc định - Standardized
df = finance.balance_sheet(period="quarter")
print(f"Shape: {df.shape}")  # (90, 6)
print(df)
