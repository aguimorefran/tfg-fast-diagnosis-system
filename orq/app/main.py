from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import List, Optional
from sklearn.feature_extraction.text import TfidfVectorizer

from uuid import uuid1, UUID
from datetime import datetime
from urllib.parse import unquote

import nmslib
import redis
import requests
import json
import editdistance

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

@app.get("/api/search_symptoms", response_model=List[dict])
def search_symptoms(query: str, exclude: Optional[str] = None):
    exclude_list = exclude.split(",") if exclude else []
    query_vector = vectorizer.transform([query]).toarray()
    ids, distances = index.knnQuery(query_vector, k=5)

    return [
        {"name": symptoms_data[id]["name"], "question": symptoms_data[id]["question_en"], "distance": float(dist)} 
        for id, dist in zip(ids, distances)
        if symptoms_data[id]["name"] not in exclude_list
    ]



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
    

@app.post("/api/diagnose_json")
def diagnose_json(data: dict):
    try:
        response = requests.post("http://fca-engine:8005/diagnose_json", data=json.dumps(data))
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/diagnose_text")
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

        return {"status": "success", "message": "Conversation saved successfully", "conv_id": str(id)}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.get("/api/get_condition_severity")
async def get_condition_severity(condition: str = Query(...)):
    try:
        condition = unquote(condition)
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        rows = session.execute('SELECT severity, name_english FROM fds.conditions WHERE name = %s ALLOW FILTERING', [condition])
        return {"severity": rows[0].severity, "name_english": rows[0].name_english}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error: " + str(e))


@app.post("/api/book_appointment")
async def book_appointment(appointment_data: dict):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        session.execute('CREATE TABLE IF NOT EXISTS fds.appointments (id uuid, dni text, conversation_id uuid, datetime timestamp, PRIMARY KEY (id))')

        id = uuid1()
        dni = appointment_data['dni']
        conversation_id = appointment_data['conversation_id']

        print(f'Conversation ID: {conversation_id}')

        dtt = datetime.now()

        session.execute(
            """
            INSERT INTO fds.appointments (id, dni, conversation_id, datetime)
            VALUES (%s, %s, %s, %s)
            """,
            (id, dni, UUID(conversation_id), dtt)
        )

        return {"status": "success", "message": "Appointment booked successfully", "appointment_id": str(id)}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    

def closest_word(word, words):
    return min(words, key=lambda x: editdistance.eval(word, x))
    
    
@app.get("/api/get_treatment")
async def get_treatment(condition: str = Query(...)):
    try:
        condition = unquote(condition)
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()

        rows = session.execute('SELECT disease FROM fds.medications')
        closest_name = closest_word(condition, [row.disease for row in rows])
        rows = session.execute('SELECT treatment FROM fds.medications WHERE disease = %s ALLOW FILTERING', [closest_name])

        print("Asked for: " + condition)
        print("Closest name: " + closest_name)
        print("Treatment: " + rows[0].treatment)
        
        return {"treatment": rows[0].treatment}
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="Error: " + str(e))

@app.get("/medicamentos/{principio_activo}")
def get_medicamentos(principio_activo: str):
    url = f"https://cima.aemps.es/cima/rest/medicamentos?practiv1={principio_activo}"
    response = requests.get(url)
    data = response.json()
    medicamentos = data['resultados']

    medicamento_con_receta = next((m for m in medicamentos if m['receta'] == True), None)
    medicamento_sin_receta = next((m for m in medicamentos if m['receta'] == False), None)
    
    if medicamento_con_receta:
        try:
            foto = next((f['url'] for f in medicamento_con_receta['fotos']), None)
        except Exception:
            foto = None

        medicamento_con_receta = {
            "informacion": medicamento_con_receta,
            "foto": foto
        }

    if medicamento_sin_receta:
        try:
            foto = next((f['url'] for f in medicamento_sin_receta['fotos']), None)
        except Exception:
            foto = None

        medicamento_sin_receta = {
            "informacion": medicamento_sin_receta,
            "foto": foto
        }

    return {
        "medicamento_con_receta": medicamento_con_receta,
        "medicamento_sin_receta": medicamento_sin_receta
    }


@app.get("/api/get_past_appointments/{dni}")
async def get_past_appointments(dni: str):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        
        query = f'SELECT * FROM fds.appointments WHERE dni = %s ALLOW FILTERING'
        appointments = session.execute(query, [dni])

        appointments_list = [{column: value for column, value in row._asdict().items()} for row in appointments]

        print(appointments_list)
        return {"status": "success", "appointments": appointments_list}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/get_past_conversations/{dni}")
async def get_past_conversations(dni: str):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()

        query = f'SELECT * FROM fds.conversations WHERE dni = %s ALLOW FILTERING'
        conversations = session.execute(query, [dni])

        conversations_list = [{column: value for column, value in row._asdict().items()} for row in conversations]

        print(conversations_list)
        return {"status": "success", "conversations": conversations_list}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    

@app.get("/api/get_medical_data")
async def get_medical_data():
    cluster = Cluster(['cassandra'], port=9042, 
                        auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
    session = cluster.connect()

    try:
        query_conversations = 'SELECT * FROM fds.conversations'
        conversations = session.execute(query_conversations)
        conversations_list = [{column: value for column, value in row._asdict().items()} for row in conversations]

        query_appointments = 'SELECT * FROM fds.appointments'
        appointments = session.execute(query_appointments)
        appointments_list = [{column: value for column, value in row._asdict().items()} for row in appointments]

        medical_data = []

        for conversation in conversations_list:
            data = {}

            data['id'] = str(conversation['id'])
            data['dni'] = conversation['dni']
            data['steps'] = conversation['steps']
            data['diagnosis'] = conversation['diagnosis']

            condition = unquote(data['diagnosis'])
            query_severity = 'SELECT severity FROM fds.conditions WHERE name_english = %s ALLOW FILTERING'
            severity = session.execute(query_severity, [condition])
            if severity:
                try:
                    data['severity'] = severity[0].severity
                except Exception as e:
                    data['severity'] = "ERROR"
            else:
                data['severity'] = None

            query_treatment = 'SELECT treatment FROM fds.medications WHERE disease = %s ALLOW FILTERING'
            treatment = session.execute(query_treatment, [condition])
            try:
                data['active_principle'] = treatment[0].treatment
            except Exception as e:
                data['active_principle'] = "ERROR"

            try:
                url = f"https://cima.aemps.es/cima/rest/medicamentos?practiv1={data['active_principle']}"
                response = requests.get(url)
                medications = response.json()['resultados']

                data['med_receta'] = next((m for m in medications if m['receta'] == True), None)
                data['med_sin_receta'] = next((m for m in medications if m['receta'] == False), None)
            except Exception as e:
                data['med_receta'] = "ERROR"
                data['med_sin_receta'] = "ERROR"

            data['appointment'] = any(appointment['conversation_id'] == conversation['id'] for appointment in appointments_list)

            medical_data.append(data)

        return {"status": "success", "medical_data": medical_data}
    except Exception as e:
        return {"status": "error", "error": str(e)}


from typing import Dict
from uuid import UUID

@app.post("/api/close_appointment")
async def close_appointment(appointment_data: dict):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()

        # First, select the IDs of the appointments associated with the given conversation ID
        select_query = 'SELECT id FROM fds.appointments WHERE conversation_id = %s ALLOW FILTERING'
        rows = session.execute(select_query, [UUID(appointment_data['id'])])

        # Then, delete each of those appointments
        for row in rows:
            delete_query = 'DELETE FROM fds.appointments WHERE id = %s IF EXISTS'
            session.execute(delete_query, [row.id])

        return {"status": "success"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


import random
import string
from faker import Faker

fake = Faker()

@app.get("/populate_convs_and_apps")
async def populate_convs_and_apps(number_of_entries: int = 100):
    try:
        cluster = Cluster(['cassandra'], port=9042, 
                          auth_provider=PlainTextAuthProvider(username='cassandra', password='cassandra'))
        session = cluster.connect()
        for _ in range(number_of_entries):
            conversation_id = uuid1()
            session.execute(
                """
                INSERT INTO fds.conversations (id, diagnosis, steps, symptoms, number_steps)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (conversation_id, 'TEST', 'TEST', 'TEST', 0)
            )

            if random.random() < 0.5:
                dni = generate_random_dni()
                session.execute(
                    """
                    INSERT INTO fds.appointments (id, dni, conversation_id, datetime)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (uuid1(), dni, conversation_id, datetime.now())
                )
        return {"status": "success"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def generate_random_dni():
    table = "TRWAGMYFPDXBNJZSQVHLCKE"
    digits = "".join([random.choice(string.digits) for _ in range(8)])
    letter = table[int(digits) % 23]
    return digits + letter
