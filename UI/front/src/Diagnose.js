import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import axios from 'axios';

const Diagnose = () => {
  const location = useLocation();
  const patientData = location.state?.patientData || {};  // Utiliza el operador opcional
  const [symptoms, setSymptoms] = useState([]);

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

  return (
    <div>
      <h2>Datos del Paciente:</h2>
      <table>
        <tr>
          <td>DNI:</td>
          <td>{patientData.dni}</td>
        </tr>
        {/* Otros datos del paciente */}
      </table>

      {/* Tabla de síntomas */}
    </div>
  );
};

export default Diagnose;
