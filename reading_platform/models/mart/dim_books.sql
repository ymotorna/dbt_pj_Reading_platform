-- all stg_books cols + author name+nationality

{{ config(materialized='table') }}

with books as (
    select *
    from {{ ref('stg_books') }}
),

authors as (
    select author_id,
        name as author_name,
        nationality as author_nationality
    from {{ ref('stg_authors') }}
)

select b.*,
       a.*
from books b
left join authors a
    on a.author_id = b.author_id


