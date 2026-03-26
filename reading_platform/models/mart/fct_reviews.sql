-- stg_reviews + sk from
        --              dim_books,
        --              dim_users
        --              dim_date
-- grain: 1 review/user for 1 book
-- incremental

{{
  config(
    materialized='incremental',
    unique_key='review_sk',
    incremental_strategy='merge'
  )
}}

with reviews as (
    select *
    from {{ ref('stg_reviews') }}

    {% if is_incremental() %}
        where created_at > (select max(created_at) from {{ this }})
    {% endif %}
),

dim_users as (
    select user_id,
        user_sk
    from {{ ref('dim_users') }}
),

dim_books as (
    select book_id,
        book_sk
    from {{ ref('dim_books') }}
),

dim_date as (
    select date_key
    from {{ ref('dim_date') }}
),

final as (
    select
        r.review_sk,
        r.review_id,
        u.user_sk,
        b.book_sk,
        d.date_key as created_at_date_fk,
        r.created_at,
        r.rating,
        r.review_text,
        r.is_verified_reader
    from reviews r
    left join dim_users u
        on r.user_id = u.user_id
    left join dim_books b
        on r.book_id = b.book_id
    left join dim_date d
        on cast(r.created_at as date) = d.date_key
)

select * from final











