import React, { useState } from 'react';
import axios from 'axios';

const PatientSearch = () => {
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
      const { dni, name, surnames, age, sex, symptoms } = patientData;

      return (
        <div>
          <h2>Data del Paciente:</h2>
          <table>
            <tbody>
              <tr>
                <th>DNI:</th>
                <td>{dni}</td>
              </tr>
              <tr>
                <th>Nombre:</th>
                <td>{name}</td>
              </tr>
              <tr>
                <th>Apellidos:</th>
                <td>{surnames}</td>
              </tr>
              <tr>
                <th>Edad:</th>
                <td>{age}</td>
              </tr>
              <tr>
                <th>Sexo:</th>
                <td>{sex}</td>
              </tr>
            </tbody>
          </table>
          <h3>Síntomas:</h3>
          <table>
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Pregunta</th>
              </tr>
            </thead>
            <tbody>
              {symptoms.map((symptom) => (
                <tr key={symptom.name}>
                  <td>{symptom.name}</td>
                  <td>{symptom.question}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    }
  };

  return (
    <div>
      <input type="text" value={dni} onChange={handleDniChange} />
      <button onClick={searchPatientData}>Buscar</button>
      {renderPatientData()}
    </div>
  );
};

export default PatientSearch;
