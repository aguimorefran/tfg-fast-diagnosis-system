import React from 'react';
import { Link } from 'react-router-dom';
import './Chat2.css';


function Portal() {
    return (
        <div>
            <Link to="/patientdata">
                <button className="button-base purple-button">Soy paciente</button>
            </Link>
            <Link to="/medicdata">
                <button className="button-base purple-button">Soy medico</button>
            </Link>
        </div>
    );
}

export default Portal;
