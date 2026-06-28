from vnstock import Finance

finance = Finance(symbol="VCI", source="KBS")

# Mode mặc định - Standardized
df = finance.income_statement(period="quarter")
print(f"Shape: {df.shape}")  # (90, 6)
print(df)
