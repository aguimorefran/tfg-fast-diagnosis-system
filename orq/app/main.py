from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import Optional

import requests
import redis
import json

app = FastAPI()

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def check_redis(host='redis', port=6379):
    try:
        redis_client = redis.Redis(host=host, port=port)
        if redis_client.ping():
            return True
        else:
            return False
    except redis.ConnectionError:
        return False

@app.get("/ping")
async def ping():
    return {"ping": "pong"}

@app.get("/pingall")
async def ping_all():
    redis_status = "up" if check_redis() else "down"
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        session.execute('SELECT now() FROM system.local')
        cassandra_status = "up"
    except:
        cassandra_status = "down"
        
    try:
        response_fds = requests.get("http://fca-engine:8005/ping")
        response_fds.raise_for_status()
        fds_status = "up"
    except:
        fds_status = "down"

    try:
        response_sas = requests.get("http://sasmock:8000/ping")
        response_sas.raise_for_status()
        sas_status = "up"
    except:
        sas_status = "down"

    return {
        "fca-engine": fds_status,
        "cassandra": cassandra_status,
        "sasmock": sas_status,
        "redis": redis_status
    }


@app.get("/api/get_patient_data/{dni}")
async def get_patient_data(dni: str):
    try:
        response_sas = requests.get(f"http://sasmock:8000/patient/{dni}")
        response_sas.raise_for_status()
        return response_sas.json()
    except:
        raise HTTPException(status_code=404, detail="Patient not found")

@app.get("/api/get_symptoms")
async def get_symptoms():
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        rows = session.execute('SELECT id, name, question_en FROM fds.evidences')
        return [{"id": row.id, "name": row.name, "question_en": row.question_en} for row in rows]
    except:
        raise HTTPException(status_code=500, detail="Internal server error")
    

@app.post("/diagnose_json")
def diagnose_json(data: dict):
    try:
        response = requests.post("http://fca-engine:8005/diagnose_json", data=json.dumps(data))
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/diagnose_text")
def diagnose_text(patient_data: str):
    try:
        url = f"http://fca-engine:8005/diagnose_text?patient_data={patient_data}"
        response = requests.post(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail="Internal server error")
