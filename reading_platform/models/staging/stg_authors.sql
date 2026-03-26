-- raw -> stg \\ +sk

select
    {{ dbt_utils.generate_surrogate_key(['author_id']) }} as author_sk,
    *

from {{ ref('raw_authors') }}





