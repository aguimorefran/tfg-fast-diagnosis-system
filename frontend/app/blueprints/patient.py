from flask import Blueprint, request, render_template
import requests

bp = Blueprint('patient', __name__, url_prefix='/')

@bp.route('/paciente', methods=['GET', 'POST'])
def paciente():
    if request.method == 'POST':
        dni = request.form.get('dni')
        response = requests.get(f'http://localhost:8000/patient/{dni}')
        if response.status_code == 200:
            patient_data = response.json()
            return render_template('patient.html', patient=patient_data)
        else:
            error_message = "No se pudo obtener la información del paciente. Por favor, inténtalo de nuevo."
            return render_template('patient.html', error=error_message)
    return render_template('patient.html')
