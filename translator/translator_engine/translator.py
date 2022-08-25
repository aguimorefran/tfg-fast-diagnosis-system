# Define a translator class

class Translator:
    def __init__(self, src_lang: str, dst_lang: str):
        self.src_lang = src_lang
        self.dst_lang = dst_lang

    def translate(self, text: str):
        return f"{text} in {self.dst_lang}"