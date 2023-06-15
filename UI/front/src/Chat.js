import React, { useState, useEffect } from 'react';
import axios from 'axios';


const Chat = ({ patientData }) => {
    const [symptoms, setSymptoms] = useState([]);
    const [enteredSymptoms, setEnteredSymptoms] = useState(patientData);
    const [diagnosisMessage, setDiagnosisMessage] = useState('');
    const [isDiagnosisSuccess, setIsDiagnosisSuccess] = useState(false);
    const [isError, setIsError] = useState(false);
    const [chatLength, setChatLength] = useState(0);
    const [enteredSymptomsInChat, setEnteredSymptomsInChat] = useState([]);

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
        if (degree == null || degree === '') {
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
                setIsError(true);
            } else if (diagnosisResponse.status[0] === 'success') {
                setDiagnosisMessage(`Diagnóstico realizado: ${diagnosisResponse.diagnosis.join(', ')}`);
                setIsDiagnosisSuccess(true);
            } else if (diagnosisResponse.status[0] === 'missing_symptoms') {
                setDiagnosisMessage('Faltan síntomas, introduzca más en el sistema.');
            }
            const chatLength = updatedPatientData.symptoms.length - patientData.symptoms.length;
            setChatLength(chatLength);
            setEnteredSymptomsInChat(updatedPatientData.symptoms.slice(patientData.symptoms.length));
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
                    <button
                        key={symptom.id}
                        onClick={() => handleSymptomClick(symptom)}
                        disabled={isDiagnosisSuccess || isError} // Desactivar botones si se completa el diagnóstico o hay un error
                    >
                        {symptom.name}
                    </button>
                ))}
            <div style={{ marginTop: '20px' }}>
                <h1 style={{ fontSize: '2em' }}>{diagnosisMessage}</h1>
                <h2>Síntomas introducidos en el chat: {enteredSymptomsInChat.map(s => s.name).join(', ')}</h2>
                <h2>Longitud de la conversación: {chatLength}</h2>
            </div>
        </div>
    );
};

export default Chat;
