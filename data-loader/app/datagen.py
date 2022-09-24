import random
import requests
import numpy as np
import datetime

from dis import dis

GENERATOR_API = "https://api.generadordni.es/v2/profiles/person"
AGE_RANGE = (0, 100)


def key_translation(key):
    keymap = {
        'nif': 'dni',
        'name': 'nombre',
        'surname': 'apellido1',
        'surnname2': 'apellido2',
        'gender': 'sexo',
        'birthdate': 'fecha_nacimiento',
        'age': 'edad',
        'phonenumber': 'telefono',
        'email': 'email',
        'municipality': 'municipio',
        'province': 'provincia',
        'address': 'direccion',
        'address_number': 'direccion_numero',
        'address_zipcode': 'codigo_postal'
    }
    if key in keymap:
        return keymap[key]
    return None


def fetch_identities():
    """Returns 100 random identities"""
    response = requests.get(GENERATOR_API)
    data = response.json()

    for identity in data:
        for key in list(identity.keys()):
            new_key = key_translation(key)
            if new_key is None:
                del identity[key]
            else:
                identity[new_key] = identity.pop(key)
        identity["edad"] = random.randint(*AGE_RANGE)
        d = identity["fecha_nacimiento"].split("/")
        try:
            identity["fecha_nacimiento"] = datetime.date(int(d[2]), int(d[1]), int(d[0]))
        except ValueError:
            print("Error parsing date", d)
            raise ValueError
        identity["sexo"] = "hombre" if identity["sexo"] == "male" else "mujer"

    if response.status_code == 200:
        return data
    else:
        raise Exception('Could not fetch random identity from generator API')


def gen_medical_record(cassandra, person_data):
    '''
    Generates random medical data from a given identity
    '''
    # TODO: añadir alergias aleatorias tanto normales como a medicamentos

    medical = {
        'cuidador_dni': '',
        'cuidador_telefono': '',
        'cuidador_nombre': '',
        'alergias': '',
        'vacunaciones': '',
        'problemas_y_episodios_activos': '',
        'recomendaciones': '',
        'tratamientos': '',
        'enfermedades': ''
    }

    edad = person_data['edad']

    if edad > 65:
        cuidador = fetch_identities()[0]
        medical['cuidador_dni'] = cuidador['dni']
        medical['cuidador_telefono'] = cuidador['telefono']
        medical['cuidador_principal'] = cuidador['nombre'] + ' ' + \
            cuidador['apellido1'] + ' ' + cuidador['apellido2']
    else:
        # fill with empty string
        medical['cuidador_dni'] = ''
        medical['cuidador_telefono'] = ''
        medical['cuidador_principal'] = ''

    # Calculate disease probability
    diseases = cassandra.execute("SELECT name, severity FROM diseases").all()
    diseases = {disease.name: {'severity': disease.severity, 'prob': (
        edad*2)/(disease.severity*10*random.uniform(0.5, 1.5))} for disease in diseases}
    total_prob = sum([diseases[disease]['prob'] for disease in diseases])
    diseases = {disease: {'severity': diseases[disease]['severity'],
                          'prob': diseases[disease]['prob']/total_prob} for disease in diseases}

    # Calculate symptoms probability
    # First replace in db the symptoms that have severity null with an average of the rest
    symptoms = cassandra.execute("SELECT * FROM symptoms").all()
    ids_severity_null = [
        symptom.id for symptom in symptoms if symptom.severity is None]
    severity_sum = sum(
        [symptom.severity for symptom in symptoms if symptom.severity is not None])
    severity_avg = severity_sum / (len(symptoms) - len(ids_severity_null))
    for id in ids_severity_null:
        cassandra.execute(
            "UPDATE symptoms SET severity = %s WHERE id = %s", (severity_avg, id))
    symptoms = cassandra.execute("SELECT * FROM symptoms").all()
    symptoms = {symptom.name: {'severity': symptom.severity, 'prob': (
        edad*2)/(symptom.severity*10*random.uniform(0.5, 1.5))} for symptom in symptoms}
    total_prob = sum([symptoms[symptom]['prob'] for symptom in symptoms])
    symptoms = {symptom: {'severity': symptoms[symptom]['severity'],
                          'prob': symptoms[symptom]['prob']/total_prob} for symptom in symptoms}

    # Add diseases, prob 0.2
    if random.random() < 0.2:
        disease = np.random.choice(list(diseases.keys()), p=list(
            diseases[disease]['prob'] for disease in diseases))
        medical['enfermedades'] = disease
        if random.random() < 0.2:
            medical['enfermedades'] += ' (severa)'
            if random.random() < 0.2:
                medical['enfermedades'] += ' (critica)'

    # Add symptoms, prob 3/4
    if random.random() < 0.75:
        symptom = np.random.choice(list(symptoms.keys()), p=list(
            symptoms[symptom]['prob'] for symptom in symptoms))
        medical['problemas_y_episodios_activos'] = symptom
        if random.random() < 0.2:
            medical['problemas_y_episodios_activos'] += ' (severo)'
            if random.random() < 0.2:
                medical['problemas_y_episodios_activos'] += ' (critico)'
        if random.random() < 0.2:
            medical['problemas_y_episodios_activos'] += ' (reciente)'

    return medical
