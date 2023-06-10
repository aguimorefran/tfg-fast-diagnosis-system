import argparse
from app import create_app

def run_with_reload():
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=True)

def run_without_reload():
    app = create_app()
    app.run(host='0.0.0.0', port=5000)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Flask Application Runner')
    parser.add_argument('--reload', action='store_true', help='Enable auto-reload')
    args = parser.parse_args()

    if args.reload:
        run_with_reload()
    else:
        run_without_reload()
