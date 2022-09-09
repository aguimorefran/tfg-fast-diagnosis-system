from plistlib import load
import pandas as pd
import re
from cassandradb import Cassandra_client
from config import DATASET_FOLDER

client = Cassandra_client()

DISEASES_FOLDER = DATASET_FOLDER + 'diseases/'

# CREATE TABLE fds.diseases (
#     id uuid,
#     name text,
#     description text,
#     symptoms text,
#     precautions text,
#     severity int,
#     PRIMARY KEY (id)
# );

# CREATE TABLE fds.symptoms (
#     id uuid,
#     name text,
#     severity int,
#     PRIMARY KEY (id)
# );

# CREATE TABLE fds.precautions (
#     id uuid,
#     name text,
#     PRIMARY KEY (id)
# );


def clean_string(string):
    string = str(string)
    string = re.sub(r'\([^)]*\)', '', string)
    string = re.sub(r'_', ' ', string)
    string = re.sub(r'\s+', ' ', string)
    return string.strip().lower()


def insert_symptom(symptom):
    query = "SELECT * FROM fds.symptoms WHERE name = '{}' ALLOW FILTERING".format(
        symptom)
    result = client.execute(query).all()
    if len(result) == 1:
        return result[0].id
    else:
        query = "INSERT INTO fds.symptoms (id, name) VALUES (uuid(), '{}')".format(
            symptom)
        client.execute(query)
        query = "SELECT * FROM fds.symptoms WHERE name = '{}' ALLOW FILTERING".format(
            symptom)
        result = client.execute(query).all()
        return result[0].id


def load_disease_symptoms():
    df = pd.read_csv(DISEASES_FOLDER + 'disease_symptoms.csv')
    df = df.applymap(clean_string)
    df = df.drop_duplicates()
    df.columns = [clean_string(col) for col in df.columns]

    for index, row in df.iterrows():
        disease = row['disease']
        symptoms = [row[col] for col in df.columns if 'symptom' in col]
        symptoms = [symptom for symptom in symptoms if symptom != 'nan']
        symptom_ids = [insert_symptom(symptom) for symptom in symptoms]
        symptom_str = '{' + ','.join(map(str, symptom_ids)) + '}'
        
        query = "INSERT INTO fds.diseases (id, name, symptoms) VALUES (uuid(), '{}', {})".format(
            disease, symptom_str)
        client.execute(query).all()
        
        print('Inserted disease: {}'.format(disease))

load_disease_symptoms()
