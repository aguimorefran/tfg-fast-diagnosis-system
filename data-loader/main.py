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
#     symptoms set<uuid>,
#     precautions set<uuid>,
#     severity int,
#     translations map<text, text>,
#     PRIMARY KEY (id)
# );

# CREATE TABLE fds.symptoms (
#     id uuid,
#     name text,
#     severity int,
#     translations map<text, text>,
#     PRIMARY KEY (id)
# );

# CREATE TABLE fds.precautions (
#     id uuid,
#     name text,
#     translations map<text, text>,
#     PRIMARY KEY (id)
# );


def clean_string(string):
    string = str(string)
    string = re.sub(r'\([^)]*\)', '', string)
    string = re.sub(r'_', ' ', string)
    string = re.sub(r'\s+', ' ', string)
    string = string[:-1] if string[-1] == '.' else string
    string = string.replace("'", '')
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

    for _, row in df.iterrows():
        disease = row['disease']
        symptoms = [row[col] for col in df.columns if 'symptom' in col]
        symptoms = [symptom for symptom in symptoms if symptom != 'nan']
        symptom_ids = [insert_symptom(symptom) for symptom in symptoms]
        symptom_str = '{' + ','.join(map(str, symptom_ids)) + '}'

        query = "INSERT INTO fds.diseases (id, name, symptoms) VALUES (uuid(), '{}', {})".format(
            disease, symptom_str)
        client.execute(query).all()

        print('Inserted disease: {}'.format(disease))


def load_disease_description():
    df = pd.read_csv(DISEASES_FOLDER + 'disease_description.csv')
    df = df.applymap(clean_string)
    df = df.drop_duplicates()
    df.columns = [clean_string(col) for col in df.columns]

    for _, row in df.iterrows():
        disease = row['disease']
        description = row['description']

        query = "SELECT * FROM fds.diseases WHERE name = '{}' ALLOW FILTERING".format(
            disease)
        result = client.execute(query).all()
        ids = '(' + ','.join(map(str, [r.id for r in result])) + ')'
        query = '''UPDATE fds.diseases SET description = '{}' WHERE id IN {}'''.format(
            description, ids)
        client.execute(query)
        print("Updated description for disease: {}".format(disease))


def load_symptom_severity():
    df = pd.read_csv(DISEASES_FOLDER + 'symptom_severity.csv')
    df = df.applymap(clean_string)
    df = df.drop_duplicates()
    df.columns = [clean_string(col) for col in df.columns]

    for _, row in df.iterrows():
        symptom = row['symptom']
        severity = row['weight']

        query = "SELECT * FROM fds.symptoms WHERE name = '{}' ALLOW FILTERING".format(
            symptom)
        result = client.execute(query).all()
        ids = '(' + ','.join(map(str, [r.id for r in result])) + ')'
        query = '''UPDATE fds.symptoms SET severity = {} WHERE id IN {}'''.format(
            severity, ids)
        client.execute(query)
        print("Updated severity for symptom: {}".format(symptom))


def update_disease_severity():
    disease_ids = "SELECT id FROM fds.diseases"
    disease_ids = [str(disease.id)
                   for disease in client.execute(disease_ids).all()]
    for disease_id in disease_ids:

        query = "SELECT symptoms FROM fds.diseases WHERE id = {}".format(
            disease_id)
        symptoms = client.execute(query).all()[0].symptoms
        symptoms = [str(symptom) for symptom in symptoms]
        query = "SELECT severity FROM fds.symptoms WHERE id IN ({})".format(
            ','.join(symptoms))
        severities = [
            symptom.severity for symptom in client.execute(query).all()]
        severities = [severity for severity in severities if severity is not None]
        severity = (sum(severities) / len(severities))
        query = "UPDATE fds.diseases SET severity = {} WHERE id = {}".format(
            severity, disease_id)
        client.execute(query)
        print("Updated severity for disease: {}".format(disease_id))

def insert_precaution(precaution):
    query = "SELECT * FROM fds.precautions WHERE name = '{}' ALLOW FILTERING".format(
        precaution)
    result = client.execute(query).all()
    if len(result) == 1:
        return result[0].id
    else:
        query = "INSERT INTO fds.precautions (id, name) VALUES (uuid(), '{}')".format(
            precaution)
        client.execute(query)
        query = "SELECT * FROM fds.precautions WHERE name = '{}' ALLOW FILTERING".format(
            precaution)
        result = client.execute(query).all()
        return result[0].id

def load_disease_precautions():
    df = pd.read_csv(DISEASES_FOLDER + 'disease_precautions.csv')
    df = df.applymap(clean_string)
    df = df.drop_duplicates()
    df.columns = [clean_string(col) for col in df.columns]

    for _, row in df.iterrows():
        disease = row['disease']
        precautions = [row[col] for col in df.columns if 'precaution' in col]
        precautions = [precaution for precaution in precautions if precaution != 'nan']
        precaution_ids = [insert_precaution(precaution) for precaution in precautions]
        precaution_str = '{' + ','.join(map(str, precaution_ids)) + '}'
        
        query = "SELECT * FROM fds.diseases WHERE name = '{}' ALLOW FILTERING".format(
            disease)
        result = client.execute(query).all()
        id = result[0].id

        query = "UPDATE fds.diseases SET precautions = {} WHERE id = {}".format(
            precaution_str, id)
        client.execute(query)
        print("Updated precautions for disease: {}".format(disease))


# load_disease_symptoms()
# load_disease_description()
# load_symptom_severity()
# update_disease_severity()
load_disease_precautions()