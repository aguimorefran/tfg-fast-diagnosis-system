import logging

logger = logging.getLogger("TRANSLATOR")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter("%(levelname)s: %(asctime)s - %(message)s",
                              "%Y-%m-%d %H:%M:%S")
ch.setFormatter(formatter)
logger.addHandler(ch)

def info(msg):
    logger.info(f"\033[1;37;40m{msg}\033[0m")

def debug(msg):
    logger.debug(f"\033[1;32;40m{msg}\033[0m")

def error(msg):
    logger.error(f"\033[1;31;40m{msg}\033[0m")