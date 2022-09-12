import requests

from config import TRANSLATOR_PORT

def ping():
    url = 'http://localhost:{}/cache/status'.format(TRANSLATOR_PORT)
    response = requests.get(url).json()
    return response['status'] == 'ok'

def translate(src_lang, dst_lang, text):
    if not ping():
        raise Exception('Translator is not available')
    url = 'http://localhost:{}/translate/?src_lang={}&dst_lang={}&text={}'.format(
        TRANSLATOR_PORT, src_lang, dst_lang, text)
    response = requests.get(url)