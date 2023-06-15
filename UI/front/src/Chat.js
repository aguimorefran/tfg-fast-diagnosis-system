import React, { useState, useEffect } from 'react';
import axios from 'axios';

const Chat = ({ patientData }) => {
    const [symptoms, setSymptoms] = useState([]);
    const [enteredSymptoms, setEnteredSymptoms] = useState(patientData);
    const [diagnosisMessage, setDiagnosisMessage] = useState('');

    useEffect(() => {
        const fetchSymptoms = async () => {
            try {
                const response = await axios.get('http://localhost:8010/api/get_symptoms');
                setSymptoms(response.data);
            } catch (error) {
                console.error(`Error fetching symptoms: ${error}`);
            }
        };

        fetchSymptoms();
    }, []);

    const handleSymptomClick = async (symptom) => {
        const degree = window.prompt('Por favor, introduzca un grado para el síntoma:', '1');
        if (degree == null || degree == '') {
            console.log('No se introdujo un grado.');
            return;
        }

        const updatedSymptoms = enteredSymptoms.symptoms.concat({
            name: symptom.name,
            degree: parseInt(degree, 10),
        });

        const updatedPatientData = {
            ...enteredSymptoms,
            symptoms: updatedSymptoms,
        };

        setEnteredSymptoms(updatedPatientData);

        try {
            console.log(updatedPatientData);
            const response = await axios.post('http://localhost:8010/diagnose_json', updatedPatientData);
            console.log(response.data);
            const diagnosisResponse = response.data;
            if (diagnosisResponse.status[0] === 'error') {
                setDiagnosisMessage('Error: No se pudo realizar el diagnóstico.');
            } else if (diagnosisResponse.status[0] === 'success') {
                setDiagnosisMessage(`Diagnóstico realizado: ${diagnosisResponse.diagnosis.join(', ')}`);
            } else if (diagnosisResponse.status[0] === 'missing_symptoms') {
                setDiagnosisMessage('Faltan síntomas, introduzca más en el sistema.');
            }
        } catch (error) {
            console.error(`Error sending patient data: ${error}`);
            setDiagnosisMessage('Error: No se pudo conectar con el servidor.');
        }
    };

    return (
        <div>
            {symptoms
                .filter(symptom => !enteredSymptoms.symptoms.find(s => s.name === symptom.name))
                .map(symptom => (
                    <button key={symptom.id} onClick={() => handleSymptomClick(symptom)}>
                        {symptom.name}
                    </button>
                ))}
            <div style={{marginTop: '20px'}}>
                <h1 style={{fontSize: '2em'}}>{diagnosisMessage}</h1>
            </div>
        </div>
    );
};

export default Chat;
