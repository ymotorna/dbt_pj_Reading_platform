-- all stg_user cols + metric cols + window funcs

{{ config(materialized='table') }}

with users as (

    select *
    from {{ ref('stg_users') }}

),

sessions as (

    select *
    from {{ ref('stg_reading_sessions') }}

),

reviews as (

    select user_id,
           review_id,
           rating
    from {{ ref('stg_reviews') }}

),

payments as (

    select user_id,
           payment_id,
           amount,
           paid_at,
           status
    from {{ ref('stg_payments') }}

),

metrics as (

    select user_id,
           count(session_id) as total_sessions,
            sum(pages_read) as total_pages_read,
            avg(datediff('minute', ended_at, started_at)) as avg_session_duration_min,
            avg(completion_pct) as avg_completion_pct,
            count(distinct book_id) as books_started,
            count(distinct case when completion_pct = 100 then book_id end) as books_completed,
            datediff('day', max(started_at), current_date) as days_since_last_session
    from sessions
    group by user_id
),

review_metrics as (

    select user_id,
        count(review_id) as total_reviews,
        avg(rating) as avg_rating_given
    from reviews
    group by user_id
),

revenue_metrics as (

    select user_id,
        sum(amount) as lifetime_payments,
        datediff('day', min(paid_at), max(paid_at)) as tenure_as_paying_user,
        count(case when status = 'failed' then payment_id end) as total_failed_payments
    from payments
    group by user_id
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
    left join metrics m on u.user_id = m.user_id
    left join review_metrics r on u.user_id = r.user_id
    left join revenue_metrics p on u.user_id = p.user_id
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


