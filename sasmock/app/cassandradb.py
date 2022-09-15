# from config import CASSANDRA_HOST, CASSANDRA_PORT, CASSANDRA_KEYSPACE
from cassandra.cluster import Cluster

CASSANDRA_HOST = 'localhost'
CASSANDRA_PORT = '9042'
CASSANDRA_KEYSPACE = 'fds'
CASSANDRA_USERNAME = 'cassandra'
CASSANDRA_PASSWORD = 'cassandra'

class Cassandra_client:
    def __init__(self):
        self.cluster = Cluster([CASSANDRA_HOST], port=CASSANDRA_PORT)
        self.session = self.cluster.connect(CASSANDRA_KEYSPACE)
        print("Dataloader connected to Cassandra")

    def execute(self, query, params=None):
        return self.session.execute(query, params)
