import os
from dotenv import load_dotenv

LOCAL = os.environ.get('LOCAL', False)

if not LOCAL:
    load_dotenv()
    CASSANDRA_HOST = os.getenv('CASSANDRA_HOST')
    CASSANDRA_PORT = os.getenv('CASSANDRA_PORT')
    CASSANDRA_KEYSPACE = os.getenv('CASSANDRA_KEYSPACE')
    CASSANDRA_USERNAME = os.getenv('CASSANDRA_USERNAME')
    CASSANDRA_PASSWORD = os.getenv('CASSANDRA_PASSWORD')
    DATASET_FOLDER = os.getenv('DATASET_FOLDER')
else:
    CASSANDRA_HOST = os.environ['CASSANDRA_HOST']
    CASSANDRA_PORT = os.environ['CASSANDRA_PORT']
    CASSANDRA_KEYSPACE = os.environ['CASSANDRA_KEYSPACE']
    CASSANDRA_USERNAME = os.environ['CASSANDRA_USERNAME']
    CASSANDRA_PASSWORD = os.environ['CASSANDRA_PASSWORD']
    DATASET_FOLDER = os.environ['DATASET_FOLDER']