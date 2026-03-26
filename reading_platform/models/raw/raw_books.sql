with sourced as (

    select * from {{ ref('books') }}

)

select * from sourced