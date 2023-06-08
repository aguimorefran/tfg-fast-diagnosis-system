from fastapi import FastAPI, HTTPException
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from typing import List
import random

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


@app.on_event("startup")
async def startup_event():
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


@app.get("/patient/{dni}")
async def read_patient(dni: str):
    if not check_dni(dni):
        raise HTTPException(status_code=400, detail="Invalid DNI")

    conditions = [row.name for row in session.execute('SELECT name FROM conditions')]
    evidences = [row.name for row in session.execute('SELECT name FROM evidences')]
    
    age = random.randint(1, 100)
    sex = random.choice(["M", "F"])
    
    if sex == "M":
        name = random.choice([row.name for row in session.execute('SELECT name FROM names_m')])
    else:
        name = random.choice([row.name for row in session.execute('SELECT name FROM names_f')])

    surnames = " ".join(random.sample([row.surname for row in session.execute('SELECT surname FROM surnames')], 2))

    symptoms = random.sample(evidences, random.randint(1, 2))

    diseases = []
    for condition in random.sample(conditions, random.randint(0, 2)):
        disease_time = random.randint(0, 9)
        diseases.append({
            "name": condition,
            "time": disease_time
        })
    
    return {
        "dni": dni,
        "name": name,
        "surnames": surnames,
        "age": age,
        "sex": sex,
        "symptoms": symptoms,
        "diseases": diseases
    }


@app.get("/ping")
async def ping():
    return {"message": "OK"}
