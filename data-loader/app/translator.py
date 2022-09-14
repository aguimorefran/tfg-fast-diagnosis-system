import requests

from config import TRANSLATOR_PORT, TRANSLATOR_HOST


def ping():
    url = 'http://{}:{}/cache/status'.format(TRANSLATOR_HOST, TRANSLATOR_PORT)
    response = requests.get(url).json()
    return response['status'] == 'ok'


def translate(src_lang, dst_lang, text):
    if not ping():
        raise Exception('Translator is not available')
    if text is None:
        return None
    if text.lower() == 'nan':
        return "nan"
    url = 'http://{}:{}/translate/?src_lang={}&dst_lang={}&text={}'.format(
        TRANSLATOR_HOST, TRANSLATOR_PORT,
        src_lang, dst_lang, text)
    response = requests.get(url)
