import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import PatientData from './PatientData';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<PatientData />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
