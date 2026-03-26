-- raw -> stg \\

select
    {{ dbt_utils.generate_surrogate_key(['session_id']) }} as session_sk,
    *

from {{ ref('raw_reading_sessions') }}





