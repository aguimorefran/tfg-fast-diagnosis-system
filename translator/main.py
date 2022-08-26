from fastapi import FastAPI, HTTPException
from translator_engine.translator import Translator as TranslatorEngine
from config import TRANSLATORS
from logger import logger as log

app = FastAPI()

translators = {}

@app.on_event("startup")
async def startup():
    '''
    Startup event
    '''
    for src, dst in TRANSLATORS:
        translator = TranslatorEngine(src, dst)
        translators[(src, dst)] = translator

@app.get("/translate/")
async def translate(src_lang: str, dst_lang: str, text: str):
    '''
    Translate text from src_lang to dst_lang
    Input:

        - src_lang: source language
        - dst_lang: destination language
        - text: text to translate
    Output:
    
        - translated text
    '''
    try:
        translator = translators[(src_lang, dst_lang)]
    except KeyError:
        log.error("Translator not found for %s-%s", src_lang, dst_lang)
        raise HTTPException(status_code=404, detail="Translator not found", headers={"X-Error": "Translator not found"})
    except Exception as e:
        log.error("Error: %s", e)
        raise HTTPException(status_code=500, detail="Error", headers={"X-Error": "Error"})
    return translator.translate(text)