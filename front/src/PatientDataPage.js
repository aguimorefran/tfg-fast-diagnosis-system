import React, { useEffect, useState } from 'react';
import PatientDataTable from './PatientDataTable';
import axios from 'axios';

function PatientTablePage() {
    const [data, setData] = useState([]);
    const [error, setError] = useState(null);

    useEffect(() => {
        axios.get('/api/get_medical_data')
            .then(response => {
                if (response.data.status === 'error') {
                    setError(response.data.error);
                } else {
                    setData(response.data.medical_data);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                setError(error.message);
            });
    }, []);

    if (error) {
        return (
            <div>
                <h1>Error cargando los datos</h1>
                <p>Aún no hay datos en la base de datos</p>
            </div>
        );
    }

    return (
        <div>
            <h1>Conversaciones completadas</h1>
            {data && data.length > 0 ? <PatientDataTable data={data} /> : 'Loading...'}
        </div>
    );
}

export default PatientTablePage;
