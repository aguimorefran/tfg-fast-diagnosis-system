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
    string = string
    string = re.sub(r'\s+', ' ', string)
    string = re.sub(r'\([^)]*\)', '', string)
    return string.strip().lower()


def fetch_insert_precaution(db_client, precaution):
    query = "SELECT id FROM fds.precautions WHERE name = '{}' ALLOW FILTERING".format(
        precaution)
    result = db_client.execute(query).all()
    if len(result) == 1:
        print("Precaution {} already exists".format(precaution))
        return result[0].id
    if len(result) > 1:
        raise Exception(
            'More than one precaution with same name: {}'.format(precaution))
    query = "INSERT INTO fds.precautions (id, name) VALUES (uuid(), '{}')".format(
        precaution)
    db_client.execute(query)
    query = "SELECT id FROM fds.precautions WHERE name = '{}' ALLOW FILTERING".format(
        precaution)
    result = db_client.execute(query).all()
    if len(result) != 1:
        raise Exception('Could not insert precaution: {}'.format(precaution))
    print("Inserted precaution: {}".format(precaution))
    return result[0].id


def fetch_insert_disease(db_client, disease_name, precautions_str):
    query = "SELECT id FROM fds.diseases WHERE name = '{}' ALLOW FILTERING".format(
        disease_name)
    result = db_client.execute(query).all()
    if len(result) == 1:
        print("Disease {} already exists".format(disease_name))
        return result[0].id
    if len(result) > 1:
        raise Exception(
            'More than one disease with same name: {}'.format(disease_name))
    query = "INSERT INTO fds.diseases (id, name, precautions) VALUES (uuid(), '{}', {})".format(
        disease_name, precautions_str)
    db_client.execute(query)
    query = "SELECT id FROM fds.diseases WHERE name = '{}' ALLOW FILTERING".format(
        disease_name)
    result = db_client.execute(query).all()
    if len(result) != 1:
        raise Exception('Could not insert disease: {}'.format(disease_name))
    print("Inserted disease: {}".format(disease_name))
    return result[0].id


def load_disease_precautions(DATASET_FOLDER):
    df_sym_prec = pd.read_csv(DISEASES_FOLDER + 'disease_precaution.csv')
    df_sym_prec.columns = [col.lower() for col in df_sym_prec.columns]
    df_sym_prec = df_sym_prec.drop_duplicates()
    df_sym_prec = df_sym_prec.fillna('')
    df_sym_prec = df_sym_prec.applymap(clean_string)

    df_sym_prec['precautions'] = df_sym_prec.apply(lambda row: [
                                                   row['precaution_1'], row['precaution_2'], row['precaution_3'], row['precaution_4']], axis=1)
    df_sym_prec = df_sym_prec.drop(
        ['precaution_1', 'precaution_2', 'precaution_3', 'precaution_4'], axis=1)

    for index, row in df_sym_prec.iterrows():
        precautions = set()
        for precaution in row['precautions']:
            if precaution != '':
                precautions.add(fetch_insert_precaution(client, precaution))
        df_sym_prec.at[index, 'precautions'] = precautions

        precautions_str = '{' + ','.join(map(str, precautions)) + '}'
        fetch_insert_disease(client, row['disease'], precautions_str)


load_disease_precautions(DISEASES_FOLDER)
