from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
import pandas as pd
import uuid
import os
import logging

# Configuración del logging
logging.basicConfig(level=logging.INFO)

# Configuración de la conexión a Cassandra
auth_provider = PlainTextAuthProvider(
    username='cassandra', password='cassandra')
cluster = Cluster(['cassandra'], port=9042, auth_provider=auth_provider)
session = cluster.connect()

# Crear el keyspace si no existe
session.execute("""
    CREATE KEYSPACE IF NOT EXISTS fds 
    WITH replication = { 'class': 'SimpleStrategy', 'replication_factor': '1' }
""")

# Usar el keyspace fds
session.set_keyspace('fds')

# Crear la tabla si no existe
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

# Verificar si la tabla está vacía
result = session.execute("SELECT COUNT(*) FROM casos_clinicos")
if result[0].count > 0:
    logging.info("La tabla ya tiene datos, no se cargará ningún dato nuevo.")
else:
    # Leer el archivo CSV con pandas
    csv_dir = os.path.join('resources', 'dataset')
    csv_files = ['release_test_patients.csv',
                 'release_train_patients.csv', 'release_validate_patients.csv']

    for csv_file in csv_files:
        df = pd.read_csv(os.path.join(csv_dir, csv_file))

        # Preprocesar los datos como en el script de R
        df = df[['AGE', 'SEX', 'EVIDENCES', 'PATHOLOGY', 'INITIAL_EVIDENCE']]

        # Insertar los datos en la tabla de Cassandra
        for index, row in df.iterrows():
            session.execute(
                """
                INSERT INTO casos_clinicos (id, AGE, SEX, EVIDENCES, PATHOLOGY, INITIAL_EVIDENCE)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (uuid.uuid4(), row['AGE'], row['SEX'], row['EVIDENCES'],
                 row['PATHOLOGY'], row['INITIAL_EVIDENCE'])
            )

    logging.info("Datos cargados correctamente")
