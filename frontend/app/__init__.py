from flask import Flask
from .blueprints.portal import bp as portal_bp
from .blueprints.patient import bp as patient_bp

def create_app():
    app = Flask(__name__, template_folder='../templates') 
    app.register_blueprint(portal_bp, url_prefix='/portal')
    app.register_blueprint(patient_bp, url_prefix='/patient')
    return app
