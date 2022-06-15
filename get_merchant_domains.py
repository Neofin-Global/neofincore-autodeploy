import argparse
from datetime import datetime, timedelta
import os

import psycopg2
from psycopg2 import Error


def get_domains() -> str:
    parser = argparse.ArgumentParser(description="Script paramenters", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--all', help='return all domains', action='store_true')
    parser.add_argument('--domain', help='main domain')
    parser.add_argument('--db_host', help='DB host')
    parser.add_argument('--db_port', help='DB port')
    parser.add_argument('--db_name', help='DB name')
    parser.add_argument('--db_user', help='DB user')
    parser.add_argument('--db_pass', help='DB pass')
    args = parser.parse_args()

    timedelta_minutes = 5

    parent_host: str = args.domain  # os.getenv("PARENT_HOST")
    postgres_host: str = args.db_host  # os.getenv("POSTGRES_HOST")
    postgres_port: str = args.db_port  # os.getenv("POSTGRES_PORT")
    postgres_db: str = args.db_name  # os.getenv("POSTGRES_DB")
    postgres_user: str = args.db_user  # os.getenv("POSTGRES_USER")
    postgres_password: str = args.db_pass  # os.getenv("POSTGRES_PASSWORD")

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
