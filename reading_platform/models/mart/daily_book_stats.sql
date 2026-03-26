-- +joined sk on session_date+book_id \\ daily info on book
-- incremental

{{ config(
    materialized='incremental',
    unique_key='book_dstat_sk'
) }}

with sessions as (

    select
        book_sk,
        started_at::date as session_date,
        session_id,
        user_sk,
        pages_read
    from{{ ref('fct_reading_sessions') }}

    {% if is_incremental() %}
        where started_at::date > (select max(session_date) from {{ this }})
    {% endif %}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['book_sk', 'session_date']) }} as book_dstat_sk,
        book_sk,
        session_date,
        count(session_id) as total_sessions,
        count(distinct user_sk) as unique_readers,
        sum(pages_read) as total_pages_read
    from sessions
    group by book_sk, session_date
)

select * from final




