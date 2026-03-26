-- seed -> raw \\ data as is

with sourced as (

    select * from {{ ref('authors') }}

)

select * from sourced