-- user metrics + window funcs \\ pull data from fct tables + dim_user

{{ config(materialized='table') }}

with users as (

    select user_sk,
        user_id,
        country,
        signup_at,
        birth_year,
        preferred_genres,
        device_type,
        is_active,
        deleted_at
    from {{ ref('dim_users') }}

),

sessions as (

    select *
    from {{ ref('fct_reading_sessions') }}

),

reviews as (

    select user_sk,
           review_id,
           rating
    from {{ ref('fct_reviews') }}

),

payments as (

    select user_sk,
           payment_id,
           payment_amount,
           started_at,
           payment_status
    from {{ ref('fct_transactions') }}

),

metrics as (
    select user_sk,
           count(session_id) as total_sessions,
            sum(pages_read) as total_pages_read,
            avg(datediff('minute', ended_at, started_at)) as avg_session_duration_min,
            avg(completion_pct) as avg_completion_pct,
            count(distinct book_sk) as books_started,
            count(distinct case when completion_pct = 100 then book_sk end) as books_completed,
            datediff('day', max(started_at), current_date) as days_since_last_session
    from sessions
    group by user_sk
),

review_metrics as (

    select user_sk,
        count(review_id) as total_reviews,
        avg(rating) as avg_rating_given
    from reviews
    group by user_sk
),

revenue_metrics as (

    select user_sk,
        sum(payment_amount) as lifetime_payments,
        datediff('day', min(started_at), max(started_at)) as tenure_as_paying_user,
        count(case when payment_status = 'failed' then payment_id end) as total_failed_payments
    from payments
    group by user_sk
),

joined as (

    select
        u.*,
        coalesce(m.total_sessions, 0) as total_sessions,
        coalesce(m.total_pages_read, 0) as total_pages_read,
        m.avg_session_duration_min,
        m.avg_completion_pct,
        coalesce(m.books_started, 0) as books_started,
        coalesce(m.books_completed, 0) as books_completed,
        m.days_since_last_session,
        coalesce(r.total_reviews, 0) as total_reviews,
        r.avg_rating_given,
        coalesce(p.lifetime_payments, 0) as lifetime_payments,
        p.tenure_as_paying_user,
        coalesce(p.total_failed_payments, 0) as total_failed_payments
    from users u
    left join metrics m on u.user_sk = m.user_sk
    left join review_metrics r on u.user_sk = r.user_sk
    left join revenue_metrics p on u.user_sk = p.user_sk
),

final as (                    -- window funcs

    select
        *,
        dense_rank() over(order by total_pages_read desc) as pages_read_rank,
        dense_rank() over(order by books_completed desc) as books_completed_rank,
        dense_rank() over(order by lifetime_payments desc) as revenue_rank
    from joined
)

select * from final