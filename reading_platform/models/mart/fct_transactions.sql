-- stg_subscriptions + stg_payments + sk from dim_users, dim_date + joined sk for subs+payment
-- grain: 1 row/payment for subscription
-- incerental

{{
  config(
    materialized='incremental',
    unique_key='transaction_sk',
    incremental_strategy='merge'
  )
}}

with subscriptions as (
    select *
    from {{ ref('stg_subscriptions') }}

    {% if is_incremental() %}
        where started_at > (select max(started_at) from {{ this }})
    {% endif %}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

users as (
    select user_id, user_sk from {{ ref('dim_users') }}
),

dim_date as (
    select date_key from {{ ref('dim_date') }}
),

joined as (
    select
        {{ dbt_utils.generate_surrogate_key(['s.subscription_id', 'p.payment_id']) }} as transaction_sk,
        s.subscription_id,
        p.payment_id,
        u.user_sk,
        d_start.date_key as start_date_sk,
        d_end.date_key as end_date_sk,
        s.started_at,
        s.plan_type,
        s.price as plan_price,
        s.renewal_type,
        s.is_active as subs_is_active,
        s.cancel_reason as subs_cancel_reason,
        coalesce(p.status, 'free') as payment_status,
        p.amount as payment_amount,
        p.currency as payment_currency,
        p.payment_method,
        p.billing_period_start,
        p.billing_period_end
    from subscriptions s
    left join payments p
        on s.subscription_id = p.subscription_id
    left join users u
        on s.user_id = u.user_id
    left join dim_date d_start
        on cast(s.started_at as date) = d_start.date_key
    left join dim_date d_end
        on cast(s.ended_at as date) = d_end.date_key
)

select * from joined





