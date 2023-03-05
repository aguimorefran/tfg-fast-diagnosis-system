import pandas as pd
import re

from cassandradb import Cassandra_client
from config import DATASET_FOLDER, BASE_LANG, LOAD_DISEASES
from translator import Translator

client = Cassandra_client()

trans = Translator('en', BASE_LANG)


# class Translator:
#     """
#     Translator class to translate text from one language to another
#     """
#     def __init__(self, src_lang: str, dst_lang: str):
#         self.src_lang = src_lang
#         self.dst_lang = dst_lang
#         self.cache = {}

#     def translate(self, text: str):
#         if text in self.cache[self.src_lang][self.dst_lang]:
#             return self.cache[self.src_lang][self.dst_lang][text]
#         else:
#             translation = translate_api(self.src_lang, self.dst_lang, text)
#             self.cache[self.src_lang][self.dst_lang][text] = translation
#             return translation

DISEASES_FOLDER = DATASET_FOLDER + 'diseases/'
DATASET_LANG = "en"

def clean_string(string):
    """
    Cleans a string by removing parenthesis, underscores, and extra spaces.
    """
    if string == 'AIDS':
        return string
    string = str(string)
    string = re.sub(r'\([^)]*\)', '', string)
    string = re.sub(r'_', ' ', string)
    string = re.sub(r'\s+', ' ', string)
    string = string[:-1] if string[-1] == '.' else string
    string = string.replace("'", '')
    return string.strip().lower()


def insert_symptom(symptom):
    """
    Inserts a symptom into the database if it does not exist.
    Returns the symptom id.
    """
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
    """
    Loads the disease symptoms from the csv file into the database.
    """
    print('Loading disease symptoms')
    df = pd.read_csv(DISEASES_FOLDER + 'disease_symptoms.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: trans.translate(x))
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


def load_disease_description():
    """
    Loads the disease description from the csv file into the database.
    """
    print('Loading disease description')
    df = pd.read_csv(DISEASES_FOLDER + 'disease_description.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: trans.translate(x))
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


def load_symptom_severity():
    """
    Loads the symptom severity from the csv file into the database.
    """
    print('Loading symptom severity')
    df = pd.read_csv(DISEASES_FOLDER + 'symptom_severity.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: trans.translate(x))
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


def update_disease_severity():
    """
    Updates the disease severity based on the symptom severity.
    """
    print('Updating disease severity')
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
        severities = [
            severity for severity in severities if severity is not None]
        severity = (sum(severities) / len(severities))
        query = "UPDATE fds.diseases SET severity = {} WHERE id = {}".format(
            severity, disease_id)
        client.execute(query)


def insert_precaution(precaution):
    """
    Inserts a precaution into the database if it does not exist.
    """
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
    """
    Loads the disease precautions from the csv file into the database.
    """
    print('Loading disease precautions')
    df = pd.read_csv(DISEASES_FOLDER + 'disease_precautions.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: trans.translate(x))
    df = df.drop_duplicates()
    df.columns = [clean_string(col) for col in df.columns]

    for _, row in df.iterrows():
        disease = row['disease']
        precautions = [row[col] for col in df.columns if 'precaution' in col]
        precautions = [
            precaution for precaution in precautions if precaution != 'nan']
        precaution_ids = [insert_precaution(
            precaution) for precaution in precautions]
        precaution_str = '{' + ','.join(map(str, precaution_ids)) + '}'

        query = "SELECT * FROM fds.diseases WHERE name = '{}' ALLOW FILTERING".format(
            disease)
        result = client.execute(query).all()
        id = result[0].id

        query = "UPDATE fds.diseases SET precautions = {} WHERE id = {}".format(
            precaution_str, id)
        client.execute(query)

def is_data_loaded():
    """
    Checks if all tables contain data.
    Used to not load the data multiple times.
    """

    query = "SELECT * FROM fds.diseases"
    result = client.execute(query).all()
    if len(result) == 0:
        return False

    query = "SELECT * FROM fds.symptoms"
    result = client.execute(query).all()
    if len(result) == 0:
        return False

    query = "SELECT * FROM fds.precautions"
    result = client.execute(query).all()
    if len(result) == 0:
        return False

    return True

if LOAD_DISEASES and not is_data_loaded():
    print('Loading diseases')
    load_disease_symptoms()
    load_disease_description()
    load_symptom_severity()
    update_disease_severity()
    load_disease_precautions()
    print('Diseases loaded in tables.')
    print('Creating feature vectors')
else:
    print('LOAD_DISEASES or is_data_loaded is False. Skipping.')