# Translator

## Description

Translator microservice. In charche of providing translations for the entire application.
The microservice is launched at 'localhost:8000' by default, or 'TRANSLATOR_HOST:TRANSLATOR_PORT' if specified.

## Endpoints

Once launched, visit http://localhost:8000/docs#/

## Requirements

Download the Pytorch package from [here](https://pypi.tuna.tsinghua.edu.cn/packages/b9/af/23c13cd340cd333f42de225ba3da3b64e1a70425546d1a59bfa42d465a5d/torch-1.12.1-cp37-cp37m-manylinux1_x86_64.whl#sha256=743784ccea0dc8f2a3fe6a536bec8c4763bd82c1352f314937cb4008d4805de1), and save it in 'translator/packages' folder with the name `torch-1.12.1-cp37-cp37m-manylinux1_x86_64.whl`.

Before executing 'docker compose', run 'sh create_requirements.sh' to create the requirements.txt file for each service.

## Env variables

Check `.env` file for env variables. This file is later loaded by the `docker-compose.yml` file.

## Run

1. Dependencies. Either install them using poetry `poetry install`, or install them manually using the `pyproject.toml` file.
2. Run `git lfs pull` to download the model files.
3. Docker. Run `docker compose up --build` to build and run the docker containers.
