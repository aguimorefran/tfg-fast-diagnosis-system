from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import List, Optional
from sklearn.feature_extraction.text import TfidfVectorizer
import nmslib
import redis
import requests
import json
from uuid import uuid1
from datetime import datetime

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

vectorizer = TfidfVectorizer()
index = nmslib.init(method='hnsw', space='cosinesimil')

def prepare_symptoms_db():
    cluster = Cluster(['cassandra'], port=9042, 
                      auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
    session = cluster.connect()
    rows = session.execute('SELECT id, name, question_en FROM fds.evidences')

    symptoms_data = [{"id": row.id, "name": row.name, "question_en": row.question_en} for row in rows]

    vectorizer.fit([x["question_en"] for x in symptoms_data])
    index.addDataPointBatch(vectorizer.transform([x["question_en"] for x in symptoms_data]).toarray())
    index.createIndex({'post': 2}, print_progress=True)

    return symptoms_data

symptoms_data = prepare_symptoms_db()

@app.get("/search_symptoms", response_model=List[dict])
def search_symptoms(query: str):
    query_vector = vectorizer.transform([query]).toarray()
    ids, distances = index.knnQuery(query_vector, k=5)
    return [{"name": symptoms_data[id]["name"], "question": symptoms_data[id]["question_en"], "distance": float(dist)} for id, dist in zip(ids, distances)]


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
    except Exception as e:
        cassandra_status = "down"
        
    try:
        response_fds = requests.get("http://fca-engine:8005/ping")
        response_fds.raise_for_status()
        fds_status = "up"
    except Exception as e:
        fds_status = "down"

    try:
        response_sas = requests.get("http://sasmock:8000/ping")
        response_sas.raise_for_status()
        sas_status = "up"
    except Exception as e:
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


@app.post("/api/save_conversation")
async def save_conversation(conversation_data: dict):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        session.execute('CREATE TABLE IF NOT EXISTS fds.conversations (id uuid, dni text, status text, diagnosis text, steps text, number_steps int, symptoms text, datetime timestamp, PRIMARY KEY (id))')

        print(conversation_data)

        id = uuid1()
        dni = conversation_data['dni']
        status = conversation_data['status']
        if 'diagnosis' in conversation_data and conversation_data['diagnosis'] != '':
            diagnosis = conversation_data['diagnosis']  
        else:
            diagnosis = None
        steps = json.dumps(conversation_data['steps'])
        number_steps = conversation_data['number_steps']
        symptoms = json.dumps(conversation_data['symptoms'])
        dtt = datetime.now()

        session.execute(
            """
            INSERT INTO fds.conversations (id, dni, status, diagnosis, steps, number_steps, symptoms, datetime)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (id, dni, status, diagnosis, steps, number_steps, symptoms, dtt)
        )

        return {"status": "success", "message": "Conversation saved successfully. ID: " + str(id)}
    except Exception as e:
        return {"status": "error", "message": str(e)}
