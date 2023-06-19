import React, { useState, useEffect } from 'react';
import axios from 'axios';

const Chat = ({ patientData, setRemainingSymptoms }) => {
    const [symptoms, setSymptoms] = useState([]);
    const [enteredSymptoms, setEnteredSymptoms] = useState(patientData);
    const [diagnosisMessage, setDiagnosisMessage] = useState('');
    const [isDiagnosisSuccess, setIsDiagnosisSuccess] = useState(false);
    const [isError, setIsError] = useState(false);
    const [chatLength, setChatLength] = useState(0);
    const [enteredSymptomsInChat, setEnteredSymptomsInChat] = useState([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState([]);
    const [conversationId, setConversationId] = useState(null);


    useEffect(() => {
        const fetchSymptoms = async () => {
            try {
                const response = await axios.get('/api/get_symptoms');
                setSymptoms(response.data);
            } catch (error) {
                console.error(`Error fetching symptoms: ${error}`);
            }
        };

        fetchSymptoms();
    }, []);

    const handleBookAppointment = async () => {
        try {
            const response = await axios.post('/api/book_appointment', {
                dni: patientData.dni,
                conversation_id: conversationId,
            });
            console.log(response.data);
            alert('Cita reservada exitosamente!');
        } catch (error) {
            console.error(`Error booking appointment: ${error}`);
            alert('Error al reservar cita.');
        }
    };

    const handleSearch = async () => {
        const discardSymptoms = enteredSymptoms.symptoms.map(s => s.name).join(",");
        try {
            const response = await axios.get(`api/search_symptoms?query=${searchQuery}&discard=${discardSymptoms}`);
            setSearchResults(response.data);
        } catch (error) {
            console.error(`Error fetching search results: ${error}`);
        }
    };

    const handleSymptomClick = async (symptom) => {
        if (enteredSymptoms.symptoms.some(s => s.name === symptom.name)) {
            alert('This symptom has already been entered.');
            return;
        }

        const degree = window.prompt('Por favor, introduzca un grado para el síntoma\nSÍNTOMA: ' + symptom.name + '\nDESCRIPCIÓN: ' + symptom.question, '1');

        const updatedSymptoms = enteredSymptoms.symptoms.concat({
            name: symptom.name,
            degree: parseFloat(degree),
        });

        const updatedPatientData = {
            ...enteredSymptoms,
            symptoms: updatedSymptoms,
        };

        setEnteredSymptoms(updatedPatientData);

        try {
            console.log(updatedPatientData);
            const response = await axios.post('api/diagnose_json', updatedPatientData);
            if (response.status === 200) {
                setRemainingSymptoms(prevSymptoms => prevSymptoms.filter(s => s.name !== symptom.name));
            }

            console.log(response.data);
            const diagnosisResponse = response.data;


            if (['error', 'success'].includes(diagnosisResponse.status[0])) {
                const steps = updatedPatientData.symptoms.slice(patientData.symptoms.length);
                const conversationData = {
                    dni: patientData.dni,
                    status: diagnosisResponse.status[0],
                    diagnosis: diagnosisResponse.status[0] === 'success' ? diagnosisResponse.diagnosis.join(', ') : '',
                    symptoms: patientData.symptoms,
                    steps: steps,
                    number_steps: steps.length,
                };

                const saveResponse = await axios.post('/api/save_conversation', conversationData);
                console.log("ID de la conversación: " + saveResponse.data.conv_id);
                if (saveResponse.data.status === "success") {
                    setConversationId(saveResponse.data.conv_id);
                }
            }

            if (diagnosisResponse.status[0] === 'error') {
                setDiagnosisMessage('Error: No se encuentra diagnóstico para los síntomas introducidos.');
                setIsError(true);
            } else if (diagnosisResponse.status[0] === 'success') {
                let severity = '';
                try {
                    const encodedDiagnosis = encodeURIComponent(diagnosisResponse.diagnosis[0]);
                    severity = await axios.get(`/api/get_condition_severity?condition=${encodeURIComponent(diagnosisResponse.diagnosis[0])}`);
                    console.log(severity.data);
                } catch (error) {
                    console.error(`Error fetching condition severity: ${error}`);
                }
                setDiagnosisMessage(`Diagnóstico realizado: ${severity.data.name_english}\nGravedad: ${severity.data.severity}/5`);
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
            <div style={{ marginTop: '20px' }}>
                <h1 style={{ fontSize: '2em' }}>{diagnosisMessage}</h1>
                <h2>Síntomas introducidos en el chat: {enteredSymptomsInChat.map(s => s.name).join(', ')}</h2>
                <h2>Longitud de la conversación: {chatLength}</h2>
            </div>
            <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search symptoms"
            />
            <button onClick={handleSearch}>Buscar</button>
            {searchResults
                .sort((a, b) => a.distance - b.distance)
                .map((result, index) => (
                    <div key={index}>
                        <button
                            onClick={() => handleSymptomClick(result)}
                            disabled={isDiagnosisSuccess || isError || enteredSymptoms.symptoms.some(s => s.name === result.name)}
                        >
                            {result.name}
                        </button>
                        <p>{`Pregunta: ${result.question}`}</p>
                        <p>{`Distancia: ${result.distance}`}</p>
                    </div>
                ))
            }
            {(isDiagnosisSuccess || isError) && conversationId && (
                <button onClick={handleBookAppointment}>Pedir cita</button>
            )}

        </div>
    );
};

export default Chat;
