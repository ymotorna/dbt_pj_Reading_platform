-- raw -> stg \\ +sk

select
    {{ dbt_utils.generate_surrogate_key(['user_id']) }} as user_sk,
    *

from {{ ref('raw_users') }}





