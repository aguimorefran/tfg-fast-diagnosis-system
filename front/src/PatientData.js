import React, { useState } from 'react';
import Chat from './Chat2';
import axios from 'axios';
import './PatientData.css';

const PatientData = () => {
    const [dni, setDni] = useState('');
    const [patientData, setPatientData] = useState(null);
    const [isChatOpen, setIsChatOpen] = useState(false);
    const [remainingSymptoms, setRemainingSymptoms] = useState([]);

    const generateRandomDNI = () => {
        let dniNum = Math.floor(Math.random() * 100000000);
        let dniChar = 'TRWAGMYFPDXBNJZSQVHLCKE';
        let letter = dniChar.charAt(dniNum % 23);
        let randomDNI = ('00000000' + dniNum.toString()).slice(-8) + letter;
        setDni(randomDNI);
    };

    const handleDniChange = (event) => {
        setDni(event.target.value);
    };

    const handleOpenChat = () => {
        setIsChatOpen(true);
    };

    const searchPatientData = async () => {
        try {
            const response = await axios.get(`/api/get_patient_data/${dni}`);
            setPatientData(response.data);
            setRemainingSymptoms(response.data.remaining_symptoms);
        } catch (error) {
            console.error(`Error fetching patient data: ${error}`);
        }
    };

    const removeSymptomFromRemaining = (symptom) => {
        setRemainingSymptoms(remainingSymptoms.filter(s => s.name !== symptom.name));
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
                    <div className="right-column">

                        <button onClick={handleOpenChat} disabled={isChatOpen}>
                            Abrir chat
                        </button>
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
            <button onClick={searchPatientData}>Buscar Paciente</button>
            <button onClick={generateRandomDNI}>DNI Aleatorio</button>
            {renderPatientData()}
        </div>
    );
};

export default PatientData;
