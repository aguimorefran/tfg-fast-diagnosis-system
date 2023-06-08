from flask import Blueprint, render_template

bp = Blueprint('portal', __name__, url_prefix='/')

@bp.route('/portal', methods=['GET'])
def portal():
    return render_template('portal.html')
