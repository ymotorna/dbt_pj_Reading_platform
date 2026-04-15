from airflow.models import Variable
from airflow.providers.postgres.hooks.postgres import PostgresHook
import duckdb
import pandas as pd
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

duckdb_path = "/usr/local/airflow/data/reading_platform.db"

def etl_tbl(tbl, col_as_watermark):
    # get watermark for tbl as Airflow Variables
    watermark_id = f'watermark_{tbl}'
    last_loaded_changes = Variable.get(watermark_id, default_var='2000-01-01')
    logger.info("watermark: %s", last_loaded_changes)

    # connect to PostgresSQL server
    hook = PostgresHook(postgres_conn_id="postgres_reading_platform")
    conn = hook.get_conn()
    cursor = conn.cursor()
    # select new/changed rows w/in last day
    query = f"""select * 
                    from {tbl} 
                    where {col_as_watermark} > '{last_loaded_changes}';"""
    cursor.execute(query)

    cols = [desc[0] for desc in cursor.description]  # colnames from query
    rows = cursor.fetchall()                         # get rows as list of tuples

    cursor.close()
    conn.close()

    # turn -> df
    df = pd.DataFrame(rows, columns=cols)
    logger.info("Extracted %d rows from %s (pg)", len(df), tbl)

    # check for [] == no new calls
    if df.empty:
        logger.info("No new data - skipping load")
        # +new watermark
        new_watermark = datetime.now().date().isoformat()
        Variable.set(watermark_id, datetime.now().date().isoformat())
        logger.info("Watermark set to %s", new_watermark)
        return

    # load data -> DuckDB
    conn_db = duckdb.connect(duckdb_path)

    try:
        conn_db.execute("create schema if not exists raw")
        if tbl == 'authors':
            conn_db.execute(f"""
                       CREATE TABLE IF NOT EXISTS raw.authors (
                           author_id   VARCHAR PRIMARY KEY,
                           name        VARCHAR,
                           nationality VARCHAR,
                           birth_year  INTEGER,
                           bio_snippet VARCHAR,
                           added_at    DATE
                       )
                   """)
            conn_db.execute("""
                    insert into raw.authors
                    select  author_id,
                           name,
                           nationality,
                           birth_year::integer,
                           bio_snippet,
                           added_at::date
                    from df
                    on conflict (author_id) do update set
                        name = excluded.name,
                        nationality = excluded.nationality,
                        bio_snippet = excluded.bio_snippet;
                    """)

        elif tbl == 'books':
                conn_db.execute(f"""
                           CREATE TABLE IF NOT EXISTS raw.books (
                                book_id              VARCHAR PRIMARY KEY,
                                author_id            VARCHAR,
                                title                VARCHAR,
                                genre_id             VARCHAR,
                                genre                VARCHAR,
                                language_code        VARCHAR,
                                published_date       DATE,
                                page_count           INTEGER,
                                added_to_platform_at DATE,
                                is_available         BOOLEAN
                           )
                       """)
                conn_db.execute("""
                        insert into raw.books
                        select  book_id,
                                author_id,
                                title,
                                genre_id,
                                genre,
                                language_code,
                                published_date::date,
                                page_count::int,
                                added_to_platform_at::DATE,
                                is_available::BOOLEAN
                        from df
                        on conflict (book_id) do update set
                            title = excluded.title,
                            genre = excluded.genre,
                            language_code = excluded.language_code,
                            is_available = excluded.is_available;
                        """)

        elif tbl == 'subscriptions':
                conn_db.execute(f"""
                               CREATE TABLE IF NOT EXISTS raw.subscriptions (
                                    subscription_id VARCHAR PRIMARY KEY,
                                    user_id         VARCHAR,
                                    plan_type       VARCHAR,
                                    started_at      TIMESTAMP,
                                    ended_at        TIMESTAMP,
                                    price           DOUBLE PRECISION,
                                    payment_method  VARCHAR,
                                    renewal_type    VARCHAR,
                                    is_active       BOOLEAN,
                                    cancel_reason   VARCHAR,
                                    last_change_at  DATE
                               )
                           """)
                conn_db.execute("""
                            insert into raw.subscriptions
                            select  subscription_id,
                                    user_id,
                                    plan_type,
                                    started_at::TIMESTAMP,
                                    ended_at::TIMESTAMP,
                                    price,
                                    payment_method,
                                    renewal_type,
                                    is_active::BOOLEAN,
                                    cancel_reason,
                                    last_change_at::DATE
                            from df
                            on conflict (subscription_id) do update set
                                plan_type = excluded.plan_type,
                                ended_at = excluded.ended_at,
                                price = excluded.price,
                                payment_method = excluded.payment_method,
                                renewal_type = excluded.renewal_type,
                                is_active = excluded.is_active,
                                cancel_reason = excluded.cancel_reason,
                                last_change_at = excluded.last_change_at;
                            """)

        elif tbl == 'users':
                conn_db.execute(f"""
                               CREATE TABLE IF NOT EXISTS raw.users (
                                    user_id          VARCHAR PRIMARY KEY,
                                    email            VARCHAR,
                                    username         VARCHAR,
                                    country_code     VARCHAR,
                                    signup_at        TIMESTAMP,
                                    birth_year       INTEGER,
                                    preferred_genres VARCHAR,
                                    device_type      VARCHAR,
                                    is_active        BOOLEAN,    
                                    deleted_at       TIMESTAMP,
                                    last_change_at   DATE
                               )
                           """)
                conn_db.execute("""
                            insert into raw.users
                            select  user_id,
                                    email,
                                    username,
                                    country_code,
                                    signup_at::TIMESTAMP,
                                    birth_year::INTEGER,
                                    preferred_genres,
                                    device_type,
                                    is_active::BOOLEAN,
                                    deleted_at::TIMESTAMP,
                                    last_change_at::DATE
                            from df
                            on conflict (user_id) do update set
                                email = excluded.email,
                                username = excluded.username,
                                country_code = excluded.country_code,
                                preferred_genres = excluded.preferred_genres,
                                device_type = excluded.device_type,
                                is_active = excluded.is_active,
                                deleted_at = excluded.deleted_at,
                                last_change_at = excluded.last_change_at;
                            """)

        logger.info("Inserted/updated %d rows into raw.%s in DuckDB", len(df), tbl)
        # set new watermark
        new_watermark =  datetime.now().date().isoformat()
        Variable.set(watermark_id, new_watermark)
        logger.info("Watermark set to %s", new_watermark)


    except Exception as e:
        logger.error("Insert into DuckDB failed: %s", e)
        raise         # Airflow raise failed for task
    finally:
        conn_db.close()