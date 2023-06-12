from flask import Blueprint, request, jsonify, render_template
from cassandra.cluster import Cluster
import requests
import json

diagnosis_bp = Blueprint('diagnosis', __name__, url_prefix='/diagnosis')

# Inicia una conexión con Cassandra
cluster = Cluster(['0.0.0.0'])  # asume que Cassandra está en localhost
session = cluster.connect('fds')  # reemplaza 'tu_keyspace' con el nombre de tu keyspace

@diagnosis_bp.route('/symptoms', methods=['GET'])
def get_symptoms():
    rows = session.execute('SELECT * FROM evidences')
    symptoms = [row.name for row in rows]
    return jsonify(symptoms)

@diagnosis_bp.route('/get_diagnosis', methods=['POST'])
def get_diagnosis():
    data = request.json
    response = requests.post('http://localhost:8005/diagnose_json', data=json.dumps(data))
    return jsonify(response.json())

@diagnosis_bp.route('/<string:dni>', methods=['GET'])
def diagnosis(dni):
    response = requests.get(f'http://0.0.0.0:8010/api/get_patient_data/{dni}')
    if response.status_code == 200:
        patient_data = response.json()
    else:
        patient_data = None
    return render_template('diagnosis.html', patient=patient_data)
