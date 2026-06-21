{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/fundamentals/ticker=*/report=income_statement/*/*/*/*.parquet',
        table_structure='ticker String, year String, quarter String, revenue String, year_revenue_growth String, quarter_revenue_growth String, cost_of_good_sold String, gross_profit String, operation_expense String, operation_profit String, year_operation_profit_growth String, quarter_operation_profit_growth String, interest_expense String, pre_tax_profit String, post_tax_profit String, share_holder_income String, year_share_holder_income_growth String, quarter_share_holder_income_growth String, ebitda String'
    ) }}
)

select * from source_data
