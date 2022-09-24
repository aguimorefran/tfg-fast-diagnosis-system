import os
from dotenv import load_dotenv

DOCKER = os.environ.get('DOCKER', False)

CASSANDRA_HOST = os.environ['CASSANDRA_HOST']
CASSANDRA_PORT = os.environ['CASSANDRA_PORT']
CASSANDRA_KEYSPACE = os.environ['CASSANDRA_KEYSPACE']
CASSANDRA_USERNAME = os.environ['CASSANDRA_USERNAME']
CASSANDRA_PASSWORD = os.environ['CASSANDRA_PASSWORD']
DATASET_FOLDER = os.environ['DATASET_FOLDER']
TRANSLATOR_PORT = os.environ['TRANSLATOR_PORT']
TRANSLATOR_HOST = os.environ['TRANSLATOR_HOST']
BASE_LANG = os.environ['BASE_LANG']
LOAD_DISEASES = os.environ['LOAD_DISEASES'] == "true"
LOAD_PEOPLE = os.environ['LOAD_PEOPLE'] == "true"
