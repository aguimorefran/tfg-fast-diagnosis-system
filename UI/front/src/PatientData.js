import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';

const PatientData = () => {
    const [dni, setDni] = useState('');
    const [patientData, setPatientData] = useState(null);

    const handleDniChange = (event) => {
        setDni(event.target.value);
    };

    const searchPatientData = async () => {
        try {
            const response = await axios.get(`http://localhost:8010/api/get_patient_data/${dni}`);
            setPatientData(response.data);
        } catch (error) {
            console.error(`Error fetching patient data: ${error}`);
        }
    };

    const renderPatientData = () => {
        if (patientData) {
            const { dni, name, surnames, age, sex, symptoms, diseases } = patientData;

            return (
                <div>
                    <h2>Data del Paciente:</h2>
                    <table>
                        <tr>
                            <td>DNI:</td>
                            <td>{dni}</td>
                        </tr>
                        <tr>
                            <td>Nombre:</td>
                            <td>{name}</td>
                        </tr>
                        <tr>
                            <td>Apellidos:</td>
                            <td>{surnames}</td>
                        </tr>
                        <tr>
                            <td>Edad:</td>
                            <td>{age}</td>
                        </tr>
                        <tr>
                            <td>Sexo:</td>
                            <td>{sex}</td>
                        </tr>
                    </table>
                    <h3>Síntomas:</h3>
                    <table>
                        {symptoms.map(symptom => (
                            <tr key={symptom.name}>
                                <td>{symptom.name}</td>
                                <td>{symptom.question}</td>
                            </tr>
                        ))}
                    </table>
                    <h3>Enfermedades:</h3>
                    <table>
                        {diseases.map(disease => (
                            <tr key={disease.name}>
                                <td>{disease.name}</td>
                                <td>{disease.time}</td>
                            </tr>
                        ))}
                    </table>
                    <div>
                        <Link to={{
                            pathname: '/diagnose',
                            state: { patientData }
                        }}>
                            Nuevo diagnóstico
                        </Link>

                    </div>
                </div>
            );
        }
    };

    return (
        <div>
            <input type="text" value={dni} onChange={handleDniChange} placeholder="Introduce DNI" />
            <button onClick={searchPatientData}>Buscar Paciente</button>
            {renderPatientData()}
        </div>
    );
};

export default PatientData;
