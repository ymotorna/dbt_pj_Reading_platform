# OLTP (PostgresSQL) -> DuckDB  \\  ETL  \\  authors/books/subscriptions/users info \\ structured data

from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from datetime import datetime, timedelta
import logging
import etl_function

logger = logging.getLogger(__name__)

# ----------------------------------------------------------------------------
def etl_authors(task_instance):
    etl_function.etl_tbl('authors', 'added_at')

def etl_books(task_instance):
    etl_function.etl_tbl('books', 'added_to_platform_at')

def etl_subscriptions(task_instance):
    etl_function.etl_tbl('subscriptions', 'last_change_at')

def etl_users(task_instance):
    etl_function.etl_tbl('users', 'last_change_at')


# ------------------------------------------------------------------

# failure callback func
def failure_callback(context):
    logger.error(
        "Task failed — task_id=%s | dag_id=%s | run_id=%s",
        context['task_instance'].task_id,
        context['dag'].dag_id,
        context['run_id']
    )


# ---------------------------------------------------------
default_args = {
    "owner": "airflow",
    "start_date": datetime(2025, 3, 14),
    # Retry & alert strategy
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'on_failure_callback': failure_callback
}

dag = DAG(
    "reading_platform_oltp",
    default_args=default_args,
    schedule="@daily",
    catchup=False
)

# ---------------------------------------------

load_new_authors = PythonOperator(
    task_id="new_authors",
    python_callable=etl_authors,
    dag=dag
)

load_new_books = PythonOperator(
    task_id="new_books",
    python_callable=etl_books,
    dag=dag
)

load_new_subscriptions = PythonOperator(
    task_id="new_subscriptions",
    python_callable=etl_subscriptions,
    dag=dag
)

load_new_users = PythonOperator(
    task_id="new_users",
    python_callable=etl_users,
    dag=dag
)



# || execution of tasks
[load_new_authors, load_new_books, load_new_subscriptions, load_new_users]





