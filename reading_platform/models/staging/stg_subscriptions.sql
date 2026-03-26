-- raw -> stg \\ +sk

select
    {{ dbt_utils.generate_surrogate_key(['subscription_id']) }} as subscription_sk,
    *

from {{ ref('raw_subscriptions') }}





