import requests

from config import TRANSLATOR_PORT, TRANSLATOR_HOST

session = requests.Session()

def translate_api(src_lang, dst_lang, text):
    text = str(text)
    if text.lower() == 'nan':
        return "nan"
    if text.isdigit():
        return text
    url = 'http://{}:{}/translate/?src_lang={}&dst_lang={}&text={}'.format(
        TRANSLATOR_HOST, TRANSLATOR_PORT,
        src_lang, dst_lang, text)
    response = session.get(url).content.decode('utf-8')
    return response[1:-1]

class Translator:
    """
    Translator class to translate text from one language to another
    """
    def __init__(self, src_lang: str, dst_lang: str):
        self.src_lang = src_lang
        self.dst_lang = dst_lang
        self.cache = {}

    def translate(self, text: str):
        if self.src_lang not in self.cache:
            self.cache[self.src_lang] = {}

        if self.dst_lang not in self.cache[self.src_lang]:
            self.cache[self.src_lang][self.dst_lang] = {}

        if text not in self.cache[self.src_lang][self.dst_lang]:
            translation = translate_api(self.src_lang, self.dst_lang, text)
            self.cache[self.src_lang][self.dst_lang][text] = translation

        return self.cache[self.src_lang][self.dst_lang][text]