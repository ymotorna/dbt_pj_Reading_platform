with sourced as (

    select * from {{ ref('payments') }}

)

select * from sourced