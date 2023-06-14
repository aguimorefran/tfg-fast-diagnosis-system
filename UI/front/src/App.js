import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import PatientData from './PatientData';
import Diagnose from './Diagnose';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<PatientData />} />
          <Route path="/diagnose" element={<Diagnose />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
