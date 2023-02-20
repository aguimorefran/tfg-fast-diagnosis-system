# Translator Microservice

This microservice provides translation of text from one language to another. It uses a Redis cache to store translations for faster retrieval. 

## Features
- Translates text from one language to another using available translators.
- Redis cache stores translations for faster retrieval.
- Provides endpoints for checking the status of the cache and getting a dump of its contents.

## Requirements
- Python 3.7
- Poetry package manager
- Redis
- Docker (optional)

## Quick Start
1. Clone the repository.
2. Navigate to the `translator` directory.
3. Create a `.env` file with the following variables:
    - `REDIS_HOST`: the Redis host.
    - `REDIS_PORT`: the Redis port.
    - `REDIS_DB`: the Redis database to use.
    - `TRANSLATORS`: a comma-separated list of translators in the form `src-lang-dst-lang`.
    - `CLEAR_CACHE`: set to `true` to clear the Redis cache on startup, or `false` otherwise.
4. Run `poetry install` to install the project dependencies.
5. Start the server using `poetry run uvicorn app.main:app --reload`.

### Docker Compose
The microservice can also be run using Docker Compose. To do so, follow these steps:
1. Navigate to the root directory of the project.
2. Run `docker-compose up translator`.
3. The server will be running at `http://localhost:8000`.

## API
- `/healthcheck`: returns the status of the server.
- `/cache/status`: returns the status of the Redis cache.
- `/cache/dump`: returns a dump of the contents of the Redis cache.
- `/get_translators`: returns a list of available translators.
- `/create_translator`: creates a new translator for the given source and destination languages.
- `/translate`: translates text from one language to another. (API endpoints are not described here.)

For more information on how to use the API, please refer to the API documentation.