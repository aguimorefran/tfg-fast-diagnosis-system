import pandas as pd
import re
import datetime

import datagen as dg
from cassandradb import Cassandra_client
from config import DATASET_FOLDER, BASE_LANG, LOAD_DISEASES, LOAD_PEOPLE
from translator import translate


client = Cassandra_client()

DISEASES_FOLDER = DATASET_FOLDER + 'diseases/'
DATASET_LANG = "en"


def clean_string(string):
    # if AIDS is in string, return AIDS
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
    print('Loading disease symptoms')
    df = pd.read_csv(DISEASES_FOLDER + 'disease_symptoms.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: translate(DATASET_LANG, BASE_LANG, x))
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
    print('Loading disease description')
    df = pd.read_csv(DISEASES_FOLDER + 'disease_description.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: translate(DATASET_LANG, BASE_LANG, x))
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
    print("Loading symptom severity")
    df = pd.read_csv(DISEASES_FOLDER + 'symptom_severity.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: translate(DATASET_LANG, BASE_LANG, x))
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
    print("Loading disease precautions")
    df = pd.read_csv(DISEASES_FOLDER + 'disease_precautions.csv')
    df = df.applymap(clean_string)
    df = df.applymap(lambda x: translate(DATASET_LANG, BASE_LANG, x))
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


print("Dataloader starting")

if LOAD_DISEASES:
    print("Loading diseases into database")
    load_disease_symptoms()
    load_disease_description()
    load_symptom_severity()
    update_disease_severity()
    load_disease_precautions()
    print("Diseases loaded into database")
else:
    print("Skipping disease loading")

    print("Loading people into database")
    n = 4
    for i in range(n):
        people = dg.fetch_identities()
        for person in people:
            # sanitize data ' and " for string values
            for key in person:
                if type(person[key]) == str:
                    person[key] = person[key].replace("'", "")
                    person[key] = person[key].replace('"', '')
            query = '''
            INSERT INTO fds.people (
                dni,
                nombre,
                apellido1,
                apellido2,
                sexo,
                fecha_nacimiento,
                edad,
                telefono,
                email,
                municipio,
                provincia,
                direccion,
                direccion_numero,
                codigo_postal) VALUES ( '{}', '{}', '{}', '{}', '{}', '{}', {}, {}, '{}', '{}', '{}', '{}', {}, {} )'''.format(
                person['dni'],
                person['nombre'],
                person['apellido1'],
                person['apellido2'],
                person['sexo'],
                person['fecha_nacimiento'],
                person['edad'],
                person['telefono'],
                person['email'],
                person['municipio'],
                person['provincia'],
                person['direccion'],
                person['direccion_numero'],
                person['codigo_postal'])

            result = client.execute(query)
            if result:
                print(person['dni'], "inserted")
            medical = dg.gen_medical_record(client, person)
            if medical['cuidador_dni'] is not None:
                query = '''
                INSERT INTO fds.medical_history (
                    dni,
                    cuidador_dni,
                    cuidador_telefono,
                    cuidador_nombre,
                    alergias,
                    vacunaciones,
                    problemas_y_episodios_activos,
                    recomendaciones,
                    tratamientos,
                    enfermedades) VALUES ( '{}', '{}', {}, '{}', '{}', '{}', '{}', '{}', '{}', '{}' )'''.format(
                    person['dni'],
                    medical['cuidador_dni'],
                    medical['cuidador_telefono'],
                    medical['cuidador_nombre'],
                    medical['alergias'],
                    medical['vacunaciones'],
                    medical['problemas_y_episodios_activos'],
                    medical['recomendaciones'],
                    medical['tratamientos'],
                    medical['enfermedades'])
            else:
                query = '''
                INSERT INTO fds.medical_history (
                    dni,
                    alergias,
                    vacunaciones,
                    problemas_y_episodios_activos,
                    recomendaciones,
                    tratamientos,
                    enfermedades) VALUES ( '{}', '{}', '{}', '{}', '{}', '{}', '{}' )'''.format(
                    person['dni'],
                    medical['alergias'],
                    medical['vacunaciones'],
                    medical['problemas_y_episodios_activos'],
                    medical['recomendaciones'],
                    medical['tratamientos'],
                    medical['enfermedades'])

            try:
                result = client.execute(query)
            except Exception as e:
                print(e)
                print(query)
                raise Exception("Error inserting medical history")
    print("People loaded into database")