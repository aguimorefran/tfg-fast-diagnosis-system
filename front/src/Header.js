import React from 'react';
import logo from './images/fdslogo-t.png';
import './Header.css';

const Header = () => (
    <header className="header">
        <div className="header-logo">
            <img src={logo} alt="Logo" />
            <p className="logo-text">Fast Diagnosis System</p>
        </div>
        <nav className="header-nav">
            <a href="/" className="base-button purple-button">Inicio</a>
        </nav>
    </header>
);

export default Header;
