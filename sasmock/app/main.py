from fastapi import FastAPI, HTTPException
from app.config import TRANSLATORS, REDIS_HOST, REDIS_PORT, REDIS_DB
from app.logger import logger as log
from cassandradb import Cassandra_client

app = FastAPI()
cassandra = Cassandra_client()


@app.on_event("startup")
async def startup():
    try:
        cassandra.execute("SELECT * FROM users")
    except Exception as e:
        log.error(e)
        raise Exception(status_code=500, detail=str(e))


##############################################################################################

@app.get("/healthcheck",)
async def healthcheck():
    '''
    Healthcheck endpoint
    '''
    return {"status": "ok"}

