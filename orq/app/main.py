from fastapi import FastAPI
from fastapi.responses import JSONResponse
import requests
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

app = FastAPI()

@app.get("/ping")
def ping():
    return JSONResponse(status_code=200, content={"message": "OK"})

@app.get("/pingall")
def ping_all():
    auth_provider = PlainTextAuthProvider(username='cassandra', password='cassandra')
    cluster = Cluster(['cassandra'], port=9042, auth_provider=auth_provider)
    session = cluster.connect()
    
    results = {}
    
    try:
        session.execute('SELECT * FROM system.local')
        results['cassandra'] = "OK"
    except Exception as e:
        results['cassandra'] = f"Failed - {str(e)}"
    
    try:
        r = requests.get('http://sasmock:8000/ping')
        r.raise_for_status()
        results['sasmock'] = "OK"
    except Exception as e:
        results['sasmock'] = f"Failed - {str(e)}"
        
    try:
        r = requests.get('http://fca-engine:8005/ping')
        r.raise_for_status()
        results['fca_engine'] = "OK"
    except Exception as e:
        results['fca_engine'] = f"Failed - {str(e)}"
    
    return JSONResponse(status_code=200, content=results)
