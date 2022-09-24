import requests

from config import TRANSLATOR_PORT, TRANSLATOR_HOST


def ping():
    url = 'http://{}:{}/cache/status'.format(TRANSLATOR_HOST, TRANSLATOR_PORT)
    response = requests.get(url).json()
    return response['status'] == 'ok'


def translate(src_lang, dst_lang, text):
    text = str(text)
    if not ping():
        raise Exception('Translator is not available')
    if text.lower() == 'nan':
        return "nan"
    if text.isdigit():
        return text
    url = 'http://{}:{}/translate/?src_lang={}&dst_lang={}&text={}'.format(
        TRANSLATOR_HOST, TRANSLATOR_PORT,
        src_lang, dst_lang, text)
    response = requests.get(url).content.decode('utf-8')
    return response[1:-1]