from fastapi import FastAPI, HTTPException
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import Optional
from pydantic import BaseModel

from conversation import start_or_continue_conversation, add_symptom, check_previous_diagnosis, get_active_session

import requests
import redis

app = FastAPI()

class SymptomModel(BaseModel):
    symptom: str
    grade: str

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

@app.get("/conversation/{dni}")
async def start_or_continue_conversation_endpoint(dni: str, continue_existing: Optional[bool] = False):
    try:
        symptoms, grades = start_or_continue_conversation(dni, continue_existing)
    except ValueError as ve:
        raise HTTPException(status_code=404, detail=str(ve))

    return {
        "status": "success",
        "symptoms": symptoms,
        "grades": grades
    }

@app.post("/conversation/{dni}/symptom")
async def add_symptom_endpoint(dni: str, symptom_data: SymptomModel):
    diagnosis_response = add_symptom(dni, symptom_data.symptom, symptom_data.grade)

    return {
        "status": diagnosis_response['status'],
        "diagnosis": diagnosis_response['diagnosis'],
    }

@app.get("/conversation/{dni}/end")
async def end_conversation(dni: str):
    diagnosis = check_previous_diagnosis(dni)
    if not diagnosis:
        raise HTTPException(status_code=404, detail=f"No diagnosis found for patient {dni}")

    return {
        "status": "success",
        "diagnosis": diagnosis,
    }

@app.get("/conversation/{dni}/check")
async def check_conversation(dni: str):
    session_data = get_active_session(dni)
    if not session_data:
        raise HTTPException(status_code=404, detail=f"No active session found for patient {dni}")

    return {
        "status": "success",
        "symptoms": session_data['symptoms'],
        "grades": session_data['grades']
    }