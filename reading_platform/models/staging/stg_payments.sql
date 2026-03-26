-- raw -> stg \\ +sk

select
    {{ dbt_utils.generate_surrogate_key(['payment_id']) }} as payment_sk,
    *

from {{ ref('raw_payments') }}





