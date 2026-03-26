-- check
SELECT count(*) FROM dim_users;
SELECT count(*) FROM dim_authors;
SELECT count(*) FROM dim_books;

SELECT count(*) FROM fct_reading_sessions;
SELECT count(*) FROM fct_reviews;
SELECT count(*) FROM fct_transactions;


-- analyse

-- user engagement
select user_id,
       country,
       total_pages_read,
       books_completed,
       round(lifetime_payments, 2) as lifetime_oayments,
       revenue_rank
from user_stats
where is_active=true
order by revenue_rank asc
limit 10;

-- genre perfomance
select genre,
       count(book_id) as num_books,
       count(distinct author_id) as num_authors,
       sum(total_readers) as total_readers,
       sum(total_Sessions) as total_sessions,
       avg(genre_avg_rating) as genre_avg_rateing
from book_performance
where is_available=true
group by genre
order by genre_avg_rateing desc;


-- revenue
select date_trunc('month', billing_period_start) as month,
    plan_type,
    sum(payment_amount) as total_revenue,
    round(sum(payment_amount) / sum(sum(payment_amount)) over () * 100, 2) as pct_of_total_revenue,
    mode() within group (order by payment_method) as top_payment_method
from fct_transactions
where payment_status='success'
group by 1,2
order by 1,2 asc;