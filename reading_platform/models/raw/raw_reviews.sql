with sourced as (

    select * from {{ ref('reviews') }}

)

select * from sourced