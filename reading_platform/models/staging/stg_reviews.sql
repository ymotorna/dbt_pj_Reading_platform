-- raw -> stg \\ +sk

select
       {{ dbt_utils.generate_surrogate_key(['review_id']) }} as review_sk,
        *
from {{ ref('raw_reviews') }}





