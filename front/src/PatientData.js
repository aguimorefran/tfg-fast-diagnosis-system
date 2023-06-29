import React, { useState } from 'react';
import Chat from './Chat2';
import axios from 'axios';
import './PatientData.css';


const PatientData = () => {
    const [dni, setDni] = useState('');
    const [patientData, setPatientData] = useState(null);
    const [isChatOpen, setIsChatOpen] = useState(false);
    const [remainingSymptoms, setRemainingSymptoms] = useState([]);

    const [isConversationsOpen, setIsConversationsOpen] = useState(false);
    const [isAppointmentsOpen, setIsAppointmentsOpen] = useState(false);

    const [conversationsData, setConversationsData] = useState(null);
    const [appointmentsData, setAppointmentsData] = useState(null);

    const [conversationsLoading, setConversationsLoading] = useState(false);
    const [conversationsError, setConversationsError] = useState(null);
    const [appointmentsLoading, setAppointmentsLoading] = useState(false);
    const [appointmentsError, setAppointmentsError] = useState(null);

    const generateRandomDNI = () => {
        let dniNum = Math.floor(Math.random() * 100000000);
        let dniChar = 'TRWAGMYFPDXBNJZSQVHLCKE';
        let letter = dniChar.charAt(dniNum % 23);
        let randomDNI = ('00000000' + dniNum.toString()).slice(-8) + letter;
        setDni(randomDNI);
    };

    const handleOpenConversations = async () => {
        setIsConversationsOpen(!isConversationsOpen);
        if (!isConversationsOpen) {
            setConversationsLoading(true);
            setConversationsError(null);
            try {
                const dniUpper = dni.split('').map(char => char.toUpperCase()).join('');
                const response = await axios.get(`/api/get_past_conversations/${dniUpper}`);
                console.log(response.data);

                // Para las conversaciones
                const conversationRows = response.data.conversations.map(conversation => {
                    return {
                        datetime: conversation.datetime,
                        n_steps: conversation.number_steps,
                        diagnosis: conversation.diagnosis
                    }
                });

                setConversationsData(conversationRows);
            } catch (error) {
                console.error(`Error fetching past conversations: ${error}`);
                setConversationsError(error);
            }
            setConversationsLoading(false);
        }
    };

    const handleOpenAppointments = async () => {
        setIsAppointmentsOpen(!isAppointmentsOpen);
        if (!isAppointmentsOpen) {
            setAppointmentsLoading(true);
            setAppointmentsError(null);
            try {
                const dniUpper = dni.split('').map(char => char.toUpperCase()).join('');
                const response = await axios.get(`/api/get_past_appointments/${dniUpper}`);
                console.log(response.data);

                // Para las citas
                const appointmentRows = response.data.appointments.map(appointment => {
                    return {
                        datetime: appointment.datetime,
                        conversationId: appointment.conversation_id
                    }
                });

                setAppointmentsData(appointmentRows);

                console.log(response.data);
            } catch (error) {
                console.error(`Error fetching past appointments: ${error}`);
                setAppointmentsError(error);
            }
            setAppointmentsLoading(false);
        }
    };

    const handleDniChange = (event) => {
        setDni(event.target.value);
    };

    const handleOpenChat = () => {
        if (isChatOpen) {
            setRemainingSymptoms(patientData.remaining_symptoms);
        }

        setIsChatOpen(!isChatOpen);
    };

    const searchPatientData = async () => {
        try {
            // Set DNI to upper. Take the chars of the string, convert them to upper and join them again
            const dniUpper = dni.split('').map(char => char.toUpperCase()).join('');
            const response = await axios.get(`/api/get_patient_data/${dniUpper}`);
            setPatientData(response.data);
            setRemainingSymptoms(response.data.remaining_symptoms);
        } catch (error) {
            console.error(`Error fetching patient data: ${error}`);
        }
    };

    const renderPatientData = () => {
        if (patientData) {
            const { dni, name, surnames, age, sex, symptoms, remaining_symptoms } = patientData;
            const sympNames = symptoms.map(symptom => symptom.name);
            const sympDegrees = Array(sympNames.length).fill(1);
            const symps = sympNames.map((name, index) => ({ name, degree: sympDegrees[index] }));

            // Elimina los duplicados en remaining_symptoms
            const uniqueRemainingSymptoms = remaining_symptoms.filter((symptom, index, self) =>
                index === self.findIndex((s) => s.name === symptom.name)
            );

            return (
                <div className="container">
                    <div className="left-column">
                        <div className="data-table-container">
                            <h2>Data del Paciente:</h2>
                            <table>
                                <tr>
                                    <th>DNI</th>
                                    <th>Nombre</th>
                                    <th>Apellidos</th>
                                    <th>Edad</th>
                                    <th>Sexo</th>
                                </tr>
                                <tr>
                                    <td>{dni}</td>
                                    <td>{name}</td>
                                    <td>{surnames}</td>
                                    <td>{age}</td>
                                    <td>{sex}</td>
                                </tr>
                            </table>
                            <h3>Síntomas:</h3>
                            <table>
                                <tr>
                                    <th>Nombre</th>
                                    <th>Grado</th>
                                    <th>Pregunta</th>
                                </tr>
                                {symptoms.map(symptom => (
                                    <tr key={symptom.name}>
                                        <td>{symptom.name}</td>
                                        <td>{symptom.degree}</td>
                                        <td>{symptom.question_en}</td>
                                    </tr>
                                ))}
                            </table>
                            <h3>Síntomas restantes:</h3>
                            <table>
                                <tr>
                                    <th>Nombre</th>
                                    <th>Pregunta</th>
                                </tr>
                                {uniqueRemainingSymptoms.map(symptom => (
                                    <tr key={symptom.name}>
                                        <td>{symptom.name}</td>
                                        <td>{symptom.question_en}</td>
                                    </tr>
                                ))}
                            </table>

                            <h2>Enfermedad esperada:</h2>
                            <p>{patientData.expected_pathology}</p>
                        </div>
                    </div>

                    <div className="right-column">
                        <div className="button-container">
                            <button className='button-base orange-button' onClick={handleOpenChat} disabled={isChatOpen}>
                                Abrir chat
                            </button>
                            <button className='button-base purple-button' onClick={handleOpenConversations}>
                                Conversaciones pasadas
                            </button>
                            <button className='button-base purple-button' onClick={handleOpenAppointments}>
                                Citas
                            </button>
                        </div>

                        {conversationsLoading && (
                            <p>Cargando conversaciones...</p>
                        )}
                        {conversationsError && (
                            <p>Error cargando las conversaciones: {conversationsError.message}</p>
                        )}
                        {isConversationsOpen && conversationsData && (
                            <div>
                                <h3>Conversaciones Pasadas:</h3>
                                <table>
                                    <tr>
                                        <th>Fecha</th>
                                        <th>Diagnóstico</th>
                                        <th>Pasos dados</th>
                                    </tr>
                                    {conversationsData.map(conversation => (
                                        <tr key={conversation.datetime}>
                                            <td>{new Date(conversation.datetime).toLocaleString()}</td>
                                            <td>{conversation.diagnosis ? conversation.diagnosis : "Ninguno"}</td>
                                            <td>{conversation.n_steps}</td>
                                        </tr>
                                    ))}
                                </table>
                            </div>
                        )}
                        {appointmentsLoading && (
                            <p>Cargando citas...</p>
                        )}
                        {appointmentsError && (
                            <p>Error cargando las citas: {appointmentsError.message}</p>
                        )}
                        {isAppointmentsOpen && appointmentsData && (
                            <div>
                                <h3>Citas Pasadas:</h3>
                                <table>
                                    <tr>
                                        <th>Fecha</th>
                                        <th>ID de la Conversación</th>
                                    </tr>
                                    {appointmentsData.map(appointment => (
                                        <tr key={appointment.datetime}>
                                            <td>{new Date(appointment.datetime).toLocaleString('es-ES', { timeZone: 'UTC' })}</td>
                                            <td>{appointment.conversationId}</td>
                                        </tr>
                                    ))}
                                </table>
                            </div>
                        )}

                        {isChatOpen && (
                            <Chat
                                patientData={{ dni: patientData.dni, sex: 'SEX_' + patientData.sex, age: patientData.age, symptoms: symps }}
                                setRemainingSymptoms={setRemainingSymptoms}
                            />
                        )}
                    </div>
                </div>

            );
        }
    };

    return (
        <div>
            <input type="text" value={dni} onChange={handleDniChange} placeholder="Introduce DNI" />
            <button className='button-base small purple-button' onClick={searchPatientData}>Buscar Paciente</button>
            <button className='button-base small purple-button' onClick={generateRandomDNI}>DNI Aleatorio</button>

            {renderPatientData()}
        </div>
    );
};

export default PatientData;
