-- reding_sessions  + sk from dim_books, dim_users, dim_date + session_duration_min col
-- grain: 1 row/session for 1 user for 1 book
-- incremental

{{
  config(
    materialized='incremental',
    unique_key='session_sk',
    incremental_strategy='merge'
  )
}}

with reading_sessions as (
    select *
    from {{ ref('stg_reading_sessions') }}
    {% if is_incremental() %}
        where started_at > (select max(started_at) from {{ this }})
    {% endif %}
),

dim_users as (
    select user_id, user_sk from {{ ref('dim_users') }}
),

dim_books as (
    select book_id, book_sk from {{ ref('dim_books') }}
),

dim_date as (
    select date_key from {{ ref('dim_date') }}
),

final as (
    select
        s.session_sk,
        s.session_id,
        b.book_sk,
        u.user_sk,
        d.date_key as start_date_fk,
        s.started_at,
        s.ended_at,
        datediff('minute', s.started_at, s.ended_at) as session_duration_min,
        s.pages_read,
        s.completion_pct,
        s.device_type
    from reading_sessions s
    left join dim_users u
        on s.user_id = u.user_id
    left join dim_books b
        on s.book_id = b.book_id
    left join dim_date d
        on cast(s.started_at as date) = d.date_key
)

select * from final



