from flask import Blueprint, render_template

portal_bp = Blueprint('portal', __name__, url_prefix='/portal')

@portal_bp.route('/', methods=['GET'])
def portal():
    return render_template('portal.html')
