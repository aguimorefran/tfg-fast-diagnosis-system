import json
import redis
from app.config import REDIS_HOST, REDIS_PORT, REDIS_DB, CLEAR_CACHE
from app.logger import logger as log


class RedisClient:
    def __init__(self):
        self.redis_host = REDIS_HOST
        self.redis_port = REDIS_PORT
        self.redis_db = REDIS_DB
        self.client = redis.Redis(
            host=self.redis_host, port=self.redis_port, db=self.redis_db)
        if CLEAR_CACHE:
            log.info('Clearing cache')
            self.client.flushdb()

    def status(self):
        return self.client.ping()

    def get_key(self, key):
        value = self.client.get(key)
        return json.loads(value) if value is not None else None

    def set_key(self, key, value):
        value = json.dumps(value)
        return self.client.set(key, value)

    def get_all_keys(self):
        return self.client.keys()

    def dump(self):
        return {key: self.get_key(key) for key in self.get_all_keys()}
