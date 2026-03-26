-- all authors cols + count total #books on platform

{{ config(materialized='table') }}

with authors as (
    select *
    from {{ ref('stg_authors') }}
),

books as (
    select book_id,
        author_id
    from {{ ref('stg_books') }}
),

final as (

    select a.*,
        count(b.book_id) as total_books
    from authors a
    left join books as b
        on a.author_id = b.author_id
    group by
        a.author_sk,
        a.author_id,
        a.name,
        a.nationality,
        a.birth_year,
        a.bio_snippet
)

select * from final


