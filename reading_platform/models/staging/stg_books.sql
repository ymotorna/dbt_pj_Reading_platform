-- raw -> stg \\ +sk

select
    {{ dbt_utils.generate_surrogate_key(['book_id']) }} as book_sk,
    *

from {{ ref('raw_books') }}





