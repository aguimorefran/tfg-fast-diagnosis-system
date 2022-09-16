import random
import requests
import numpy as np

from dis import dis
from cassandradb import Cassandra_client

cassandra = Cassandra_client()

GENERATOR_API = "https://api.generadordni.es/v2/profiles/person"
AGE_RANGE = (0, 100)

def gen_ten_identities():
    """Returns 100 random identities"""
    response = requests.get(GENERATOR_API)
    data = response.json()

    for identity in data:
        identity["age"] = random.randint(*AGE_RANGE)

    if response.status_code == 200:
        return data
    
    
def gen_medical_record(person_data):
    '''
    Generates random medical data from a given identity
    '''

    age = person_data['age']

    diseases = cassandra.execute("SELECT name, severity FROM diseases").all()
    diseases = {disease.name: {'severity': disease.severity, 'prob': (age*2)/(disease.severity*10*random.uniform(0.5, 1.5))} for disease in diseases}
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

    #TODO: añadir cuidador si la persona es mayor de 65 años aleatoriamente
    #TODO: añadir alergias aleatorias
    #TODO: añadir vacunas aleatorias
    

    if random.random() < 0.2:
        disease = np.random.choice(list(diseases.keys()), p=list(diseases[disease]['prob'] for disease in diseases))
        medical['enfermedades'] = disease
        if random.random() < 0.2:
            medical['enfermedades'] += ' (severa)'
            if random.random() < 0.2:
                medical['enfermedades'] += ' (critica)'

    person_data.update(medical)
    return person_data
    
    
person = gen_ten_identities()[0]
person = gen_medical_record(person)
print(person)