with sourced as (

    select * from {{ ref('reading_sessions') }}

)

select * from sourced