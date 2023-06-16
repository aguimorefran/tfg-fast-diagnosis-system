from fastapi import FastAPI, HTTPException
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import List
import random
import redis
import json
from uuid import UUID


REDIS_DB = 1
r = None 

app = FastAPI()
auth_provider = PlainTextAuthProvider(username='cassandra', password='cassandra')
cluster = Cluster(['cassandra'], port=9042, auth_provider=auth_provider)
session = cluster.connect('fds')

def check_dni(dni):
    tabla_letras = 'TRWAGMYFPDXBNJZSQVHLCKE'
    dni = dni.upper().strip()
    if len(dni) != 9:
        return False
    dni_numeros = dni[:-1]
    dni_letra = dni[-1]
    if not dni_numeros.isdigit():
        return False
    dni_numeros = int(dni_numeros)
    letra_calc = tabla_letras[dni_numeros % 23]
    if letra_calc == dni_letra:
        return True
    
    return False

def is_valid_uuid(val):
    try:
        UUID(str(val))
        return True
    except ValueError:
        return False
    

def clean_evidences_string(evidences_str):
    evidences_list_str = evidences_str[1:-1].split(',')
    s = [symptom.strip().strip('\'').strip('\"') for symptom in evidences_list_str]
    s = [symptom.split('_$_')[0] for symptom in s]
    s = [symptom.split('_@_')[0] for symptom in s]
    return s



@app.on_event("startup")
async def startup_event():
    global r, test_case_ids
    r = redis.Redis(host='redis', port=6379, db=REDIS_DB)

    with open('names_f.txt', 'r') as f:
        names_f = [line.strip() for line in f.readlines()]
    with open('names_m.txt', 'r') as f:
        names_m = [line.strip() for line in f.readlines()]
    with open('surnames.txt', 'r') as f:
        surnames = [line.strip() for line in f.readlines()]
    
    session.execute("""
        CREATE TABLE IF NOT EXISTS names_f (
            name text PRIMARY KEY
        )
    """)
    session.execute("""
        CREATE TABLE IF NOT EXISTS names_m (
            name text PRIMARY KEY
        )
    """)
    session.execute("""
        CREATE TABLE IF NOT EXISTS surnames (
            surname text PRIMARY KEY
        )
    """)

    result = session.execute("SELECT COUNT(*) FROM names_f")
    if result[0].count == 0:
        for name in names_f:
            session.execute("INSERT INTO names_f (name) VALUES (%s)", (name,))

    result = session.execute("SELECT COUNT(*) FROM names_m")
    if result[0].count == 0:        
        for name in names_m:
            session.execute("INSERT INTO names_m (name) VALUES (%s)", (name,))

    result = session.execute("SELECT COUNT(*) FROM surnames")
    if result[0].count == 0:
        for surname in surnames:
            session.execute("INSERT INTO surnames (surname) VALUES (%s)", (surname,))

    test_case_ids = [row.id for row in session.execute('SELECT id FROM test_cases')]


@app.get("/patient/{dni}")
async def read_patient(dni: str):
    global r, test_case_ids
    if not check_dni(dni):
        raise HTTPException(status_code=400, detail="Invalid DNI")

    patient_data = r.get(dni)

    if patient_data is None:
        test_case_id = random.choice(test_case_ids)
        test_case = session.execute('SELECT * FROM test_cases WHERE id = %s', [test_case_id])[0]
    
        if test_case is None:
            raise HTTPException(status_code=500, detail="No test cases available")

        id, age, evidences_str, initial_evidence, pathology, sex = test_case
        all_evidences = clean_evidences_string(evidences_str) + [initial_evidence]

        if sex == "M":
            name = random.choice([row.name for row in session.execute('SELECT name FROM names_m')])
        else:
            name = random.choice([row.name for row in session.execute('SELECT name FROM names_f')])

        surnames = " ".join(random.sample([row.surname for row in session.execute('SELECT surname FROM surnames')], 2))

        symptoms_list = []
        for symptom_name in all_evidences:
            print("Fetching question for symptom: ", symptom_name)
            question_en = session.execute('SELECT question_en from fds.evidences WHERE name = %s ALLOW FILTERING', [symptom_name])[0].question_en
            symptoms_list.append({
                "name": symptom_name,
                "question_en": question_en,
                "degree": round(random.uniform(0.5, 1), 2)
            })

        symptoms_list = [dict(t) for t in {tuple(d.items()) for d in symptoms_list}]
        selected = random.sample(symptoms_list, random.randint(1, 2))

        # Remove duplicates from both
        new_symptoms_list = []
        for s in symptoms_list:
            name, question_en, degree = s["name"], s["question_en"], s["degree"]
            if name not in [symptom["name"] for symptom in selected]:
                new_symptoms_list.append({
                    "name": name,
                    "question_en": question_en,
                    "degree": degree
                })

        symptoms_list = new_symptoms_list

        new_selected = []
        for s in selected:
            name, question_en, degree = s["name"], s["question_en"], s["degree"]
            if name not in [symptom["name"] for symptom in new_selected]:
                new_selected.append({
                    "name": name,
                    "question_en": question_en,
                    "degree": degree
                })

        selected = new_selected
        

        patient_data = {
            "dni": dni,
            "name": name,
            "surnames": surnames,
            "age": age,
            "sex": sex,
            "symptoms": selected,
            "remaining_symptoms": [symptom for symptom in symptoms_list if symptom not in selected],
            "expected_pathology": pathology
        }
        
        r.setex(dni, 300, json.dumps(patient_data))
    
    else:
        patient_data = json.loads(patient_data)
    
    return patient_data






@app.get("/ping")
async def ping():
    return {"message": "OK"}
