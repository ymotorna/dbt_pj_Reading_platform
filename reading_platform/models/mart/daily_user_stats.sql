-- +joined sk on session_date+user_id \\ daily info on user activity
-- incremental predicate logic \\ check only last 30 days

{{ config(
    materialized='incremental',
    unique_key='user_dstat_sk',
    incremental_predicates=["session_date >= current_date - interval '30 days'"]
) }}

with sessions as (

    select
        user_sk,
        started_at::date as session_date,
        session_id,
        pages_read,
        session_duration_min
    from{{ ref('fct_reading_sessions') }}

    {% if is_incremental() %}
        where started_at::date > (select max(session_date) from {{ this }})
    {% endif %}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['user_sk', 'session_date']) }} as user_dstat_sk,
        user_sk,
        session_date,
        count(session_id) as total_sessions,
        sum(pages_read) as total_pages_read,
        sum(session_duration_min) as total_min_spent
    from sessions
    group by user_sk, session_date
)

select * from final




