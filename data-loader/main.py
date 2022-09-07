import pandas as pd
import re

from cassandradb import Cassandra_client
from config import DATASET_FOLDER


client = Cassandra_client()

DISEASES_FOLDER = DATASET_FOLDER + 'diseases/'


def clean_string(string):
    string = string.strip().lower()
    string = re.sub(r'\s+', ' ', string)
    string = re.sub(r'\([^)]*\)', '', string)
    return string


# Database structurer
# CREATE TABLE fds.diseases (
#     id int PRIMARY KEY,
#     name text,
#     description text,
#     symptoms_id set<int>,
#     precautions_id set<int>
# );

# CREATE TABLE fds.symptoms (
#     id int PRIMARY KEY,
#     name text,
#     severity int
# );

# CREATE TABLE fds.precautions (
#     id int PRIMARY KEY,
#     name text,
# );

def fetch_or_insert_precaution(db_client, precaution):


def load_symptoms_severity(DATASET_FOLDER):
    df_sym_prec = pd.read_csv(DISEASES_FOLDER + 'disease_precaution.csv')
    df_sym_prec.columns = [col.lower() for col in df_sym_prec.columns]
    df_sym_prec = df_sym_prec.fillna('')
    df_sym_prec = df_sym_prec.applymap(clean_string)

    # Create a column with list of precautions for each disease.
    df_sym_prec['precautions'] = df_sym_prec.apply(lambda row: [
                                                   row['precaution_1'], row['precaution_2'], row['precaution_3'], row['precaution_4']], axis=1)
    df_sym_prec = df_sym_prec.drop(
        ['precaution_1', 'precaution_2', 'precaution_3', 'precaution_4'], axis=1)

    # For every precaution in column precaution
    # Fetch or insert precaution in db. Replace name with id.
    for index, row in df_sym_prec.iterrows():
        precautions = []
        for precaution in row['precautions']:
            if precaution != '':
                precautions.append(
                    fetch_or_insert_precaution(client, precaution))
        df_sym_prec.at[index, 'precautions'] = precautions


load_symptoms_severity(DISEASES_FOLDER)
