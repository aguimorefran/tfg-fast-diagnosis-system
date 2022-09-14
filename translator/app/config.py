import os

REDIS_DB = os.environ['REDIS_DB']
REDIS_HOST = os.environ['REDIS_HOST']
REDIS_PORT = os.environ['REDIS_PORT']
TRANSLATORS = [tuple(translator.split('-'))
               for translator in os.environ['TRANSLATORS'].split(',')]
CLEAR_CACHE = os.environ['CLEAR_CACHE'] == 'true'