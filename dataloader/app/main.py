from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
import pandas as pd
import uuid
import os
import logging

logging.basicConfig(level=logging.INFO)

MAX_INSERTS = 500000

auth_provider = PlainTextAuthProvider(
    username='cassandra', password='cassandra')
cluster = Cluster(['cassandra'], port=9042, auth_provider=auth_provider)
session = cluster.connect()

session.execute("""
    CREATE KEYSPACE IF NOT EXISTS fds 
    WITH replication = { 'class': 'SimpleStrategy', 'replication_factor': '1' }
""")

session.set_keyspace('fds')

session.execute("""
    CREATE TABLE IF NOT EXISTS casos_clinicos (
        id UUID PRIMARY KEY,
        AGE int,
        SEX text,
        EVIDENCES text,
        PATHOLOGY text,
        INITIAL_EVIDENCE text
    )
""")

result = session.execute("SELECT COUNT(*) FROM casos_clinicos")
inserted_n = 0
if result[0].count > 0:
    logging.info("La tabla ya tiene datos, no se cargará ningún dato nuevo.")
else:
    csv_dir = os.path.join('resources', 'dataset')
    csv_files = ['release_test_patients.csv',
                 'release_train_patients.csv', 'release_validate_patients.csv']

    for csv_file in csv_files:
        df = pd.read_csv(os.path.join(csv_dir, csv_file))

        df = df[['AGE', 'SEX', 'EVIDENCES', 'PATHOLOGY', 'INITIAL_EVIDENCE']]

        for index, row in df.iterrows():
            session.execute(
                """
                INSERT INTO casos_clinicos (id, AGE, SEX, EVIDENCES, PATHOLOGY, INITIAL_EVIDENCE)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (uuid.uuid4(), row['AGE'], row['SEX'], row['EVIDENCES'],
                 row['PATHOLOGY'], row['INITIAL_EVIDENCE'])
            )
            inserted_n += 1
            if inserted_n % (df.shape[0] // 20) == 0:
                logging.info(f"{inserted_n / df.shape[0] * 100}% inserted from {csv_file}, {inserted_n} inserted in total")
            if inserted_n >= MAX_INSERTS:
                logging.info(f"Inserted {inserted_n} rows, stopping")
                break

    logging.info("Datos cargados correctamente")