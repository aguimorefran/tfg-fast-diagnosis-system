from fastapi import FastAPI, HTTPException
from translator_engine.translator import Translator as TranslatorEngine
from cache.redis import redis_client
from config import TRANSLATORS, REDIS_HOST, REDIS_PORT, REDIS_DB
from logger import logger as log

app = FastAPI()

translators = {}
redis_client = redis_client()


@app.on_event("startup")
async def startup():
    try:
        for src, dst in TRANSLATORS:
            translators[(src.strip(), dst.strip())] = TranslatorEngine(
                src.strip(), dst.strip())
        if not redis_client.status():
            raise Exception('Redis server is not running')
        else:
            log.info('Redis connection ok for {}:{}, db {}'.format(
                REDIS_HOST, REDIS_PORT, REDIS_DB))
    except Exception as e:
        log.error(e)
        raise HTTPException(status_code=500, detail=str(e))


##############################################################################################

@app.get("/cache/status")
async def get_cache_status():
    '''
    Get cache status
    '''
    try:
        if redis_client.status():
            return {"status": "ok", "numbe_of_keys": len(redis_client.get_all_keys())}
        else:
            raise Exception('Redis server is not running or not connected')
    except Exception as e:
        log.error(e)
        raise HTTPException(status_code=500, detail="Server error")


@app.get("/cache/dump")
async def get_cache_dump():
    '''
    Get cache dump
    '''
    try:
        if redis_client.status():
            return {"dump": redis_client.dump()}
        else:
            raise Exception('Redis server is not running or not connected')
    except Exception as e:
        log.error(e)
        raise HTTPException(status_code=500, detail="Server error")


@app.get("/get_translators")
async def get_translators():
    '''
    Returns available initialized translators
    '''
    try:
        return [{"src": src, "dst": dst} for src, dst in translators]
    except Exception as e:
        log.error(e)
        raise HTTPException(status_code=500, detail="Server error")


@app.post("/create_translator")
async def create_translator(src: str, dst: str):
    #TODO: fix new translator giving KeyError
    '''
    Create new translator
    Input:

        - src: source language
        - dst: destination language

    Output:

        - status: status of operation
    '''
    try:
        if (src, dst) in translators:
            return {"status": "ok", "message": "Translator already exists"}
        translators[(src, dst)] = TranslatorEngine(src, dst)
        return {"status": "ok", "message": "Translator created"}
    except Exception as e:
        log.error(e)
        raise HTTPException(status_code=500, detail="Server error")


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
        translation = translator.translate(text)
    except KeyError:
        raise HTTPException(status_code=404, detail="Translator not found")
    except Exception as e:
        log.error("Error in translation call: %s", e)
        raise HTTPException(status_code=500, detail="Error",
                            headers={"X-Error": "Error"})

    return translation
