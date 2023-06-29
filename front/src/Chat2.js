import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import './Chat2.css';
import fdsLogo from './images/fdslogo-t.png';

const Message = ({ message }) => {
    return (
        <div className={`message ${message.type}`}>
            {message.type === 'system' && <img src={fdsLogo} alt="profile" />}
            <div dangerouslySetInnerHTML={{ __html: message.text }}></div>
        </div>
    );
};


const Chat = ({ patientData, setRemainingSymptoms }) => {
    const [symptoms, setSymptoms] = useState([]);
    const [enteredSymptoms, setEnteredSymptoms] = useState(patientData);
    const [isDiagnosisSuccess, setIsDiagnosisSuccess] = useState(false);
    const [isError, setIsError] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState([]);
    const [conversationId, setConversationId] = useState(null);
    const [chatMessages, setChatMessages] = useState([{ type: 'system', text: 'Bienvenido, por favor introduzca sus síntomas.', time: new Date() }]);
    const [startTime, setStartTime] = useState(null);
    const [treatment, setTreatment] = useState('');
    const [medicine, setMedicine] = useState({ prescription: null, nonPrescription: null });
    const messagesEndRef = useRef(null);
    const [selectedSymptom, setSelectedSymptom] = useState(null);



    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    };

    useEffect(scrollToBottom, [chatMessages]);


    useEffect(() => {
        setStartTime(Date.now());
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

    const handleMedicineMessage = (medicineType, medicineData) => {
        setChatMessages(prevMessages => [...prevMessages,
        {
            type: 'system',
            text: `<h3>${medicineType}</h3>
                   <p><b>Nombre:</b> ${medicineData.informacion.nombre}</p>
                   <img class="medicine-img" src=${medicineData.foto} alt="${medicineType}" />`,
            time: new Date()
        }]);
    };

    const handleBookAppointment = async () => {
        try {
            const response = await axios.post('/api/book_appointment', {
                dni: patientData.dni,
                conversation_id: conversationId,
            });
            console.log(response.data);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: `Cita reservada exitosamente. ID de la cita: ${response.data.appointment_id}`, time: new Date() }]);
        } catch (error) {
            console.error(`Error booking appointment: ${error}`);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error al reservar cita.', time: new Date() }]);
        }
    };

    const handleTreatment = async (condition) => {
        try {
            const treatmentResponse = await axios.get(`/api/get_treatment?condition=${encodeURIComponent(condition)}`);
            setTreatment(treatmentResponse.data.treatment);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: `Tratamiento: ${treatmentResponse.data.treatment}`, time: new Date() }]);

            const medicineResponse = await axios.get(`/medicamentos/${encodeURIComponent(treatmentResponse.data.treatment)}`);

            if (medicineResponse.data.medicamento_con_receta) {
                handleMedicineMessage('Medicamento con receta', medicineResponse.data.medicamento_con_receta);
            }

            if (medicineResponse.data.medicamento_sin_receta) {
                handleMedicineMessage('Medicamento sin receta', medicineResponse.data.medicamento_sin_receta);
            }

        } catch (error) {
            console.error(`Error fetching treatment and medicine: ${error}`);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error: No se pudo obtener el tratamiento y el medicamento.', time: new Date() }]);
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

    const handleSymptomClick = (symptom) => {
        setSelectedSymptom(symptom);
    };

    const handleSymptomDegreeClick = async (symptom, degree) => {

        setSelectedSymptom(null);
        if (enteredSymptoms.symptoms.some(s => s.name === selectedSymptom.name)) {
            alert('Este síntoma ya ha sido ingresado.');
            return;
        }

        const updatedSymptoms = enteredSymptoms.symptoms.concat({
            name: selectedSymptom.name,
            degree: degree,
        });

        const updatedPatientData = {
            ...enteredSymptoms,
            symptoms: updatedSymptoms,
        };

        setEnteredSymptoms(updatedPatientData);
        setChatMessages(prevMessages => [...prevMessages, { type: 'user', text: `<b><u>Síntoma ingresado:</b></u> ${symptom.name}<br/><b><u>Descripción:</b></u> ${symptom.question}`, time: new Date() }]);

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

                let severity = '';
                let diagnosisNameEnglish = '';
                try {
                    const encodedDiagnosis = encodeURIComponent(diagnosisResponse.diagnosis[0]);
                    const severityResponse = await axios.get(`/api/get_condition_severity?condition=${encodeURIComponent(diagnosisResponse.diagnosis[0])}`);
                    severity = severityResponse.data.severity;
                    diagnosisNameEnglish = severityResponse.data.name_english;
                    console.log(severity.data);
                } catch (error) {
                    console.error(`Error fetching condition severity: ${error}`);
                }

                // change name to english
                if (diagnosisNameEnglish) {
                    conversationData.diagnosis = diagnosisNameEnglish;
                }

                const saveResponse = await axios.post('/api/save_conversation', conversationData);
                if (saveResponse.data.status === "success") {
                    setConversationId(saveResponse.data.conv_id);
                    message += 'Conversación guardada. ';
                }
                const endTime = Date.now();
                const elapsedTime = ((endTime - startTime) / 1000).toFixed(2);
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: `El diagnóstico tardó ${elapsedTime} segundos.`, time: new Date() }]);
            }

            if (diagnosisResponse.status[0] === 'error') {
                setIsError(true);
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error: No se encuentra diagnóstico para los síntomas introducidos.', time: new Date() }]);
            } else if (diagnosisResponse.status[0] === 'success') {
                let severity = '';
                let diagnosisNameEnglish = '';
                try {
                    const encodedDiagnosis = encodeURIComponent(diagnosisResponse.diagnosis[0]);
                    const severityResponse = await axios.get(`/api/get_condition_severity?condition=${encodeURIComponent(diagnosisResponse.diagnosis[0])}`);
                    severity = severityResponse.data.severity;
                    diagnosisNameEnglish = severityResponse.data.name_english;
                    console.log(severity.data);
                } catch (error) {
                    console.error(`Error fetching condition severity: ${error}`);
                }
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: `<b>Diagnóstico realizado:</b> <span style="font-size:120%;">${diagnosisNameEnglish}</span><br/><b>Gravedad:</b> ${severity}/5`, time: new Date() }]);
                setIsDiagnosisSuccess(true);
                handleTreatment(diagnosisNameEnglish);

            } else if (diagnosisResponse.status[0] === 'missing_symptoms') {
                setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Faltan síntomas, introduzca más en el sistema.', time: new Date() }]);
            }
        } catch (error) {
            console.error(`Error sending patient data: ${error}`);
            setChatMessages(prevMessages => [...prevMessages, { type: 'system', text: 'Error: No se pudo conectar con el servidor.', time: new Date() }]);
        }

        setSelectedSymptom(null);

    };

    return (
        <div className="chat-container">
            <div className="chat-window">
                {chatMessages.map((message, index) => {
                    const messageTime = new Date(message.time);
                    return (
                        <div key={index} className={`chat-message ${message.type}`}>
                            <div className="chat-message-content">
                                <Message message={message} />
                                <span className="chat-message-time">{messageTime.getHours().toString().padStart(2, '0')}:{messageTime.getMinutes().toString().padStart(2, '0')}</span>
                            </div>
                        </div>
                    );
                })}
                <div ref={messagesEndRef} />
            </div>
            <div className="input-and-buttons-section">
                <input
                    className="chat-input"
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search symptoms"
                />
                <button className="button-base purple-button" onClick={handleSearch}>Buscar</button>
            </div>
            <hr className="hr" />
            {selectedSymptom === null ? (
                searchResults
                    .sort((a, b) => a.distance - b.distance)
                    .map((result, index) => (
                        <button
                            key={index}
                            className="button-base purple-button"
                            onClick={() => handleSymptomClick(result)}
                            disabled={isDiagnosisSuccess || isError || enteredSymptoms.symptoms.some(s => s.name === result.name)}
                        >
                            {result.name + ': ' + result.question}
                        </button>
                    ))
            ) : (
                <div>
                    <p>Selecciona el grado del síntoma: {selectedSymptom.name}</p>
                    <button className="button-base purple-button" onClick={() => handleSymptomDegreeClick(selectedSymptom, 0.3)}>Bajo</button>
                    <button className="button-base purple-button" onClick={() => handleSymptomDegreeClick(selectedSymptom, 0.6)}>Medio</button>
                    <button className="button-base purple-button" onClick={() => handleSymptomDegreeClick(selectedSymptom, 1.0)}>Alto</button>

                </div>
            )}
            {isDiagnosisSuccess && (
                <>
                    {medicine.prescription && (
                        <div>
                            <h3>Medicamento con receta:</h3>
                            <p>{medicine.prescription.informacion.nombre}</p>
                            <img src={medicine.prescription.foto} alt="Medicamento con receta" />
                        </div>
                    )}
                    {medicine.nonPrescription && (
                        <div>
                            <h3>Medicamento sin receta:</h3>
                            <p>{medicine.nonPrescription.informacion.nombre}</p>
                            <img src={medicine.nonPrescription.foto} alt="Medicamento sin receta" />
                        </div>
                    )}
                </>
            )}
            {(isDiagnosisSuccess || isError) && (
                <button className="button-base orange-button" onClick={handleBookAppointment}>Pedir cita</button>
            )}

        </div>

    );
};

export default Chat;
