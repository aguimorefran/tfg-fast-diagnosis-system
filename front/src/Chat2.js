import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './Chat2.css';

const Chat = ({ patientData, setRemainingSymptoms }) => {
    const [symptoms, setSymptoms] = useState([]);
    const [enteredSymptoms, setEnteredSymptoms] = useState(patientData);
    const [isDiagnosisSuccess, setIsDiagnosisSuccess] = useState(false);
    const [isError, setIsError] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState([]);
    const [conversationId, setConversationId] = useState(null);
    const [chatMessages, setChatMessages] = useState([{ type: 'system', text: 'Bienvenido, por favor introduzca sus síntomas.', time: new Date() }]);

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
        setChatMessages(prevMessages => [...prevMessages, { type: 'user', text: `Síntoma ingresado: ${symptom.name}`, time: new Date() }]);

        try {
            const response = await axios.post('api/diagnose_json', updatedPatientData);
            if (response.status === 200) {
                setRemainingSymptoms(prevSymptoms => prevSymptoms.filter(s => s.name !== symptom.name));
            }

            const diagnosisResponse = response.data;
            let message = '';

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
                if (saveResponse.data.status === "success") {
                    setConversationId(saveResponse.data.conv_id);
                    message += 'Conversación guardada. ';
                }
            }

            if (diagnosisResponse.status[0] === 'error') {
                setIsError(true);
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error: No se encuentra diagnóstico para los síntomas introducidos.', time: new Date() }]);
            } else if (diagnosisResponse.status[0] === 'success') {
                let severity = '';
                try {
                    const encodedDiagnosis = encodeURIComponent(diagnosisResponse.diagnosis[0]);
                    severity = await axios.get(`/api/get_condition_severity?condition=${encodeURIComponent(diagnosisResponse.diagnosis[0])}`);
                    console.log(severity.data);
                } catch (error) {
                    console.error(`Error fetching condition severity: ${error}`);
                }
                setIsDiagnosisSuccess(true);
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: `Diagnóstico realizado: ${diagnosisResponse.diagnosis[0]}\nGravedad: ${severity.data.severity}/5`, time: new Date() }]);
            } else if (diagnosisResponse.status[0] === 'missing_symptoms') {
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Faltan síntomas, introduzca más en el sistema.', time: new Date() }]);
            }
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: message, time: new Date() }]);
        } catch (error) {
            console.error(`Error sending patient data: ${error}`);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error: No se pudo conectar con el servidor.', time: new Date() }]);
        }
    };

    return (
        <div className="chat-container">
            <div className="chat-window">
                {chatMessages.map((message, index) => {
                    const messageTime = new Date(message.time);
                    return (
                        <div key={index} className={`chat-message ${message.type}`}>
                            <div className="chat-message-content">
                                <p>{message.text}</p>
                                <span className="chat-message-time">{messageTime.getHours().toString().padStart(2, '0')}:{messageTime.getMinutes().toString().padStart(2, '0')}</span>
                            </div>
                        </div>
                    );
                })}
            </div>
            <div className="chat-input-section">
                <input
                    className="chat-input"
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search symptoms"
                />
                <button className="chat-button" onClick={handleSearch}>Buscar</button>
                {searchResults
                    .sort((a, b) => a.distance - b.distance)
                    .map((result, index) => (
                        <button
                            key={index}
                            className="chat-symptom-button"
                            onClick={() => handleSymptomClick(result)}
                            disabled={isDiagnosisSuccess || isError || enteredSymptoms.symptoms.some(s => s.name === result.name)}
                        >
                            {result.name}
                            <p>{result.question}</p>
                        </button>
                    ))
                }
                {(isDiagnosisSuccess || isError) && conversationId && (
                    <button className="chat-button" onClick={handleBookAppointment}>Pedir cita</button>
                )}
            </div>
        </div>
    );
};

export default Chat;
