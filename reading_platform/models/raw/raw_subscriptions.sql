with sourced as (

    select * from {{ ref('subscriptions') }}

)

select * from sourced