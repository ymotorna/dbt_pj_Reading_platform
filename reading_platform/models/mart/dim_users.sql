-- all stg_user cols

{{ config(materialized='table') }}

select *
from {{ ref('stg_users') }}


