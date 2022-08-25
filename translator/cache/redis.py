# Class that defines the connection and the methods to interact with the redis cache
import redis
import os

from logger import logger as log

class redis_driver:
    def __init__(self):
        self.redis_host = os.environ['REDIS_HOST']
        self.redis_port = os.environ['REDIS_PORT']
        self.redis_db = os.environ['REDIS_DB']
        self.redis_client = redis.Redis(host=self.redis_host, port=self.redis_port, db=self.redis_db)
