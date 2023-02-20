# Translator microservice

Translator microservice is a service that provides an API to translate texts from one language to another. It is built using FastAPI and Redis for caching.

## Features

- Provides API endpoints for translating texts, creating new translators, and getting information about available translators.
- Supports caching using Redis, to speed up translation requests.
- Easy to deploy with Docker.

## Requirements

- Python 3.7 or later
- Poetry for installing dependencies
- Docker for containerization

## Quick Start

1. Clone the repository
2. Install dependencies using `poetry install`
3. Start the Redis server using `docker-compose up -d`
4. Run the service using `uvicorn app.main:app --host 0.0.0.0 --port 8000`

## API

The Translator microservice provides the following endpoints:

- `/healthcheck`: A healthcheck endpoint that returns a status of "ok" when the service is running.
- `/cache/status`: Returns the status of the Redis cache and the number of keys it contains.
- `/cache/dump`: Returns a dump of the Redis cache.
- `/get_translators`: Returns the available initialized translators.
- `/create_translator`: Creates a new translator.
- `/translate`: Translates a text from the source language to the destination language.