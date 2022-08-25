from fastapi import FastAPI
from translator_engine.translator import Translator as TranslatorEngine

app = FastAPI()

# Initialize a translator engine for en-es and es-en
translator_en_es = TranslatorEngine("en", "es")
translator_es_en = TranslatorEngine("es", "en")

available_translators = {
    "en-es": translator_en_es,
    "es-en": translator_es_en,
}


@app.get("/")
async def root():
    return {"message": "Hello World"}
