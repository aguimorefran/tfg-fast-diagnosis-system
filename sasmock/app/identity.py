import random
import requests
from dis import dis

from cassandradb import Cassandra_client

cassandra = Cassandra_client()

GENERATOR_API = "https://api.generadordni.es/v2/profiles/person"
AGE_RANGE = (0, 100)

def gen_ten_identities():
    """Returns a random identity."""
    response = requests.get(GENERATOR_API)
    data = response.json()

    for identity in data:
        identity["age"] = random.randint(*AGE_RANGE)

    if response.status_code == 200:
        return data
    
    
def gen_medical_record(data):
    '''
    Generates random medical data from a given identity
    '''

    age = data['age']

    diseases = cassandra.execute("SELECT name, severity FROM diseases").all()
    diseases = {disease.name: {'severity': disease.severity, 'prob': (age*2)/(disease.severity*10*random.uniform(0.5, 1.5))} for disease in diseases}
    # normalize probabilities to be between 0 and 1
    total_prob = sum([diseases[disease]['prob'] for disease in diseases])
    diseases = {disease: {'severity': diseases[disease]['severity'], 'prob': diseases[disease]['prob']/total_prob} for disease in diseases}

    medical = {
        'telefono_de_referencia' : '',
        'cuidador_principal' : '',
        'alergias' : '',
        'vacunaciones' : '',
        'problemas_y_episodios_activos' : '',
        'recomendaciones' : '',
        'tratamientos' : '',
        'enfermedades': ''
    }

    print(age)
    print(diseases)
    
person = gen_ten_identities()[0]

gen_medical_record(person)