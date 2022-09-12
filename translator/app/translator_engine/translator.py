from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
from app.logger import logger as log
from app.cache.redis import RedisClient

rd = RedisClient()


class Translator:
    def __init__(self, src_lang: str, dst_lang: str):
        self.src_lang = src_lang
        self.dst_lang = dst_lang

        path = "app/translator_engine/Helsinki-NLP/opus-mt-{}-{}".format(src_lang, dst_lang)
        self.tokenizer = AutoTokenizer.from_pretrained(
            "Helsinki-NLP/opus-mt-" + self.src_lang + "-" + self.dst_lang)

        self.model = AutoModelForSeq2SeqLM.from_pretrained(
            path,
            local_files_only=True)
        log.info(
            "Translator initialized for {} -> {}".format(self.src_lang, self.dst_lang))

    def is_translated(self, text: str):
        cached = rd.get_key(text)
        if cached is not None and cached[self.src_lang][self.dst_lang] is not None and cached[self.src_lang][self.dst_lang] is not "":
            return True

    def model_translate(self, text: str):
        input_ids = self.tokenizer(text, return_tensors="pt").input_ids
        outputs = self.model.generate(input_ids=input_ids, num_beams=4)
        return self.tokenizer.batch_decode(outputs, skip_special_tokens=True, clean_up_tokenization_spaces=True)[0]

    def translate(self, text: str):
        if self.is_translated(text):
            return rd.get_key(text)[self.src_lang][self.dst_lang]
        else:
            translation = self.model_translate(text)
            ok = rd.set_key(
                text, {self.src_lang: {self.dst_lang: translation}})
            if not ok:
                log.error("Error saving translation to cache")
            return translation
