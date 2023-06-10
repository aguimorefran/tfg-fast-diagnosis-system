from flask import Blueprint, request, render_template
import requests

patient_bp = Blueprint('patient', __name__, url_prefix='/patient')

@patient_bp.route('/paciente', methods=['GET', 'POST'])
def paciente():
    patient_data = None
    if request.method == 'POST':
        dni = request.form.get('dni')
        response = requests.get(f'http://0.0.0.0:8000/patient/{dni}')
        if response.status_code == 200:
            patient_data = response.json()
        else:
            patient_data = {"error": "No se pudo obtener la información del paciente. Por favor, inténtalo de nuevo."}
    return render_template('patient.html', patient=patient_data)