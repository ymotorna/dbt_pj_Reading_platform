-- metrics + window funcs \\ pull data from fct tables + dim_books

{{ config(materialized='table') }}

with books as (
    select *
    from {{ ref('dim_books') }}
),

sessions as (

    select book_sk,
        user_sk,
        session_id,
        pages_read,
        completion_pct
    from {{ ref('fct_reading_sessions') }}
),

reviews as (

    select book_sk,
        review_id,
        rating,
        is_verified_reader
    from {{ ref('fct_reviews') }}
),

reach_metrics as (

    select book_sk,
        count(distinct user_sk) as total_readers,
        count(session_id) as total_sessions,
        avg(completion_pct) as avg_completion_pct,
        round(count(distinct case when completion_pct=100 then user_sk end) / count(distinct user_sk), 2) as completion_rate,
        avg(pages_read) as avg_pages_per_session
    from sessions
    group by book_sk
),

social_metrics as (

    select
        book_sk,
        count(review_id) as total_reviews,
        avg(rating) as avg_rating,
        round(count(distinct case when is_verified_reader=true then review_id end) / count(distinct review_id), 2)*100 as verified_review_rate
    from reviews
    group by book_sk
),

joined as (

    select
        b.*,
        coalesce(r.total_readers, 0) as total_readers,
        coalesce(r.total_sessions, 0) as total_sessions,
        r.avg_completion_pct,
        r.completion_rate,
        r.avg_pages_per_session,
        coalesce(s.total_reviews, 0) as total_reviews,
        s.avg_rating,
        s.verified_review_rate
    from books b
    left join reach_metrics r
        on b.book_sk = r.book_sk
    left join social_metrics s
        on b.book_sk = s.book_sk
),

final as (

    select *,
        avg(avg_rating) over(partition by genre) as genre_avg_rating,
        avg(completion_rate) over(partition by genre) as genre_avg_completion_rate
    from joined
)

select * from final



