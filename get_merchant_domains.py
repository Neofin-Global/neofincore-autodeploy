import argparse
from datetime import datetime, timedelta
import os

import psycopg2
from psycopg2 import Error


def get_domains() -> str:
    parser = argparse.ArgumentParser(description="Script paramenters", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--all', help='return all domains', action='store_true')
    args = parser.parse_args()

    timedelta_minutes = 3

    parent_host: str = os.getenv("PARENT_HOST")
    postgres_host: str = os.getenv("POSTGRES_HOST")
    postgres_port: str = os.getenv("POSTGRES_PORT")
    postgres_db: str = os.getenv("POSTGRES_DB")
    postgres_user: str = os.getenv("POSTGRES_USER")
    postgres_password: str = os.getenv("POSTGRES_PASSWORD")

    conn_kw = dict(
        host=postgres_host,
        port=postgres_port,
        database=postgres_db,
        user=postgres_user,
        password=postgres_password,
    )
    # Connect to an existing database
    with psycopg2.connect(**conn_kw) as connection:
        # Create a cursor to perform database operations
        cursor = connection.cursor()
        try:
            # Executing a SQL query
            if args.all is True:
                cursor.execute(f"SELECT subdomain FROM public.bnpl_merchant WHERE created_dt >='{created_from}';")
            else:
                created_from: datetime = datetime.now() - timedelta(minutes=timedelta_minutes)
                cursor.execute(f"SELECT subdomain FROM public.bnpl_merchant WHERE created_dt >='{created_from}';")

            # Fetch result
            records = cursor.fetchall()  # [('subdomain1', 'subdomain2')]
            if records:
                return " ".join([f"{s[0]}.{parent_host}" for s in records])  # "subdomain1 subdomain2"

        except (Exception, Error) as error:
            raise Exception(f"Error while connecting to PostgreSQL {error}")
    return ""

if __name__ == "__main__":
    print(get_domains())
