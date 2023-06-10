from flask import Flask
from .blueprints.portal import portal_bp
from .blueprints.patient import patient_bp

def create_app():
    app = Flask(__name__, template_folder='../templates', static_folder='../static')
    app.register_blueprint(portal_bp)
    app.register_blueprint(patient_bp)
    return app
