from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
import pandas as pd
import uuid
import os
import logging
import json
import requests
import zipfile
import csv

logging.basicConfig(level=logging.INFO)

MAX_INSERTS = 10000

auth_provider = PlainTextAuthProvider(
    username='cassandra', password='cassandra')
cluster = Cluster(['cassandra'], port=9042, auth_provider=auth_provider)
session = cluster.connect()
dataset_dir = os.path.join('resources', 'dataset')

def download_data():
    """
    Download and extract data files from given urls
    """

    # URLs to download the data
    JSONS = {
        "release_conditions.json": "https://figshare.com/ndownloader/files/35829014",
        "release_evidences.json": "https://figshare.com/ndownloader/files/35829017"
    }
    ZIPS = [
      "https://figshare.com/ndownloader/files/35945966",
      "https://figshare.com/ndownloader/files/35945969",
      "https://figshare.com/ndownloader/files/35945972"
    ]

    # Create the data directory if it doesn't exist
    if not os.path.exists(dataset_dir):
        os.makedirs(dataset_dir)

    # Download JSON files
    for filename, url in JSONS.items():
        file_path = os.path.join(dataset_dir, filename)
        if not os.path.exists(file_path):
            r = requests.get(url, allow_redirects=True)
            open(file_path, 'wb').write(r.content)

    # Download and extract ZIP files
    for url in ZIPS:
        filename = os.path.join(dataset_dir, os.path.basename(url))
        if not os.path.exists(filename):
            r = requests.get(url, allow_redirects=True)
            open(filename, 'wb').write(r.content)
            with zipfile.ZipFile(filename, 'r') as zip_ref:
                zip_ref.extractall(dataset_dir)
            os.remove(filename)

    # Print all contents of the data directory
    logging.info("Contents of the data directory:")
    for root, dirs, files in os.walk(dataset_dir):
        for file in files:
            logging.info(os.path.join(root, file))


def load_medical_cases():
    """
    Load medical cases from csv files into Cassandra

    Parameters
    ----------
    None

    Returns
    -------
    None
    """
    logging.info("Loading medical cases into Cassandra")
    session.execute("""
        CREATE KEYSPACE IF NOT EXISTS fds 
        WITH replication = { 'class': 'SimpleStrategy', 'replication_factor': '1' }
    """)

    session.set_keyspace('fds')

    tables = ['train_cases', 'validate_cases', 'test_cases']
    for table in tables:
        session.execute(f"""
            CREATE TABLE IF NOT EXISTS {table} (
                id UUID PRIMARY KEY,
                AGE int,
                SEX text,
                EVIDENCES text,
                PATHOLOGY text,
                INITIAL_EVIDENCE text
            )
        """)

    csv_files = {
        'train_cases': 'release_train_patients.csv', 
        'validate_cases': 'release_validate_patients.csv',
        'test_cases': 'release_test_patients.csv'
    }

    for table, csv_file in csv_files.items():
        result = session.execute(f"SELECT COUNT(*) FROM {table}")
        inserted_n = 0
        if result[0].count > 0:
            logging.info(f"La tabla {table} ya tiene datos, no se cargará ningún dato nuevo.")
            continue

        df = pd.read_csv(os.path.join(dataset_dir, csv_file))

        df = df[['AGE', 'SEX', 'EVIDENCES', 'PATHOLOGY', 'INITIAL_EVIDENCE']]

        for index, row in df.iterrows():
            session.execute(
                f"""
                INSERT INTO {table} (id, AGE, SEX, EVIDENCES, PATHOLOGY, INITIAL_EVIDENCE)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (uuid.uuid4(), row['AGE'], row['SEX'], row['EVIDENCES'], row['PATHOLOGY'], row['INITIAL_EVIDENCE'])
            )
            inserted_n += 1
            if inserted_n % (df.shape[0] // 20) == 0:
                logging.info("%s%% inserted from %s, %s inserted in total", round(inserted_n / df.shape[0] * 100), csv_file, inserted_n)
            if inserted_n >= MAX_INSERTS:
                logging.info("Inserted MAX_ROWS=%s, stopping", inserted_n)
                break

    logging.info("Medical cases loaded successfully")


def load_cond_names():
    """
    Load condition names from json file into Cassandra
    """
    logging.info("Loading condition names into Cassandra")

    session.execute("""
        CREATE TABLE IF NOT EXISTS conditions (
            id UUID PRIMARY KEY,
            name text,
            severity int,
            name_english text
        )
    """)

    result = session.execute("SELECT COUNT(*) FROM conditions")
    if result[0].count > 0:
        logging.info("Table conditions already has data, not loading.")
        return

    cond_file = os.path.join(dataset_dir, 'release_conditions.json')
    with open(cond_file) as f:
        conditions = json.load(f)
    
    counter = 0
    for name, details in conditions.items():
        severity = details.get('severity', None)
        name_english = details.get('cond-name-eng', None)
        
        session.execute(
            """
            INSERT INTO conditions (id, name, severity, name_english)
            VALUES (%s, %s, %s, %s)
            """,
            (uuid.uuid4(), name, severity, name_english)
        )
        counter += 1

    logging.info("Conditions loaded successfully. %s conditions loaded", counter)



def load_ev_names():
    """
    Load evidence names from json file into Cassandra
    """
    logging.info("Loading evidence names into Cassandra")

    session.execute("""
        CREATE TABLE IF NOT EXISTS evidences (
            id UUID PRIMARY KEY,
            name text,
            question_en text
        )
    """)

    result = session.execute("SELECT COUNT(*) FROM evidences")
    if result[0].count > 0:
        logging.info("Table evidences already has data, not loading.")
        return

    ev_file = os.path.join(dataset_dir, 'release_evidences.json')
    with open(ev_file) as f:
        evidences = json.load(f)
    
    counter = 0
    for name, ev in evidences.items():
        try:
            session.execute(
                """
                INSERT INTO evidences (id, name, question_en)
                VALUES (%s, %s, %s)
                """,
                (uuid.uuid4(), name, ev.get('question_en', None))
            )
            counter += 1
        except Exception as e:
            logging.error(f"Error when inserting evidence {name} into Cassandra: {str(e)}")
            
    logging.info("Evidences loaded successfully. %s evidences loaded", counter)


def load_med_names():
    """
    Load medication names from csv file into Cassandra
    """
    logging.info("Loading medication names into Cassandra")

    session.execute("""
        CREATE TABLE IF NOT EXISTS medications (
            id UUID PRIMARY KEY,
            disease text,
            treatment text
        )
    """)

    result = session.execute("SELECT COUNT(*) FROM medications")
    if result[0].count > 0:
        logging.info("Table medications already has data, not loading.")
        return

    meds_file = os.path.join(dataset_dir, 'meds.csv')
    
    with open(meds_file, 'r') as f:
        reader = csv.reader(f)
        next(reader)
        medications = list(reader)

    counter = 0
    for row in medications:
        disease = row[0]
        treatment = row[1]

        session.execute(
            """
            INSERT INTO medications (id, disease, treatment)
            VALUES (%s, %s, %s)
            """,
            (uuid.uuid4(), disease, treatment)
        )
        counter += 1

    logging.info("Medications loaded successfully. %s medications loaded", counter)


if __name__ == "__main__":
    download_data()
    load_medical_cases()
    load_cond_names()
    load_ev_names()
    load_med_names()