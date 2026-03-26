-- fully generated dates tbl
-- took part from https://medium.com/@aleksej.gudkov/justification-for-a-dim-date-table-in-data-warehousing-147fcdcaa487

{{ config(materialized='table') }}

WITH date_spine AS (
    SELECT unnest(generate_series(
        CAST('2019-01-01' AS TIMESTAMP),
        CAST('2030-12-31' AS TIMESTAMP),
        INTERVAL '1 day'
    )) AS date
)

SELECT date AS date_key,
    strftime(date, '%Y-%m-%d') as full_date,
    extract(dow FROM date) as day_of_week_num,
    extract(week FROM date) as week_num,
    extract(month FROM date) as month_num,
    extract(quarter FROM date) as quarter_num,
    extract(year FROM date) as year,
    case when (extract(dow from date) in (0,6)) then false
        else true
    end as is_weekday
FROM date_spine





