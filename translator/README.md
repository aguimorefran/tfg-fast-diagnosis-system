# Translator

## Description

Translator microservice. In charche of providing translations for the entire application.
The microservice is launched at 'localhost:8000' by default, or 'TRANSLATOR_HOST:TRANSLATOR_PORT' if specified.

## Endpoints

Once launched, visit http://localhost:8000/docs#/

## Requirements

Download the Pytorch package from [here](https://pytorch.org/get-started/locally/), and save it in 'translator/packages' folder.

Before executing 'docker compose', run 'sh create_requirements.sh' to create the requirements.txt file for each service.

## Env variables

Check `.env` file for env variables. This file is later loaded by the `docker-compose.yml` file.

## Testing
