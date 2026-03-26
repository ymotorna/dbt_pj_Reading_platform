with sourced as (

    select * from {{ ref('users') }}

)

select * from sourced