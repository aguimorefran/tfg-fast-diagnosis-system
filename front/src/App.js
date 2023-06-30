// App.js
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import PatientData from './PatientData';
import PatientTablePage from './PatientDataPage';
import Portal from './Portal';
import Header from './Header';

function App() {
  return (
    <Router>
      <div className="App">
        <Header />
        <Routes>
          <Route path="/" element={<Portal />} />
          <Route path="/patientdata" element={<PatientData />} />
          <Route path="/medicdata" element={<PatientTablePage />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
