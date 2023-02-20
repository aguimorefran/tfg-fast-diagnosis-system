# Data Loader Microservice

The Data Loader Microservice is a Python-based application that loads the datasets of symptoms, allergies, and diseases into a Cassandra database. The service also provides translation and cleaning functionalities to these datasets.

## Features

- Loads datasets of symptoms, allergies, and diseases to a Cassandra database.
- Provides translation and cleaning functionalities for the datasets.
- Reads configuration parameters from the `.env` file.
- Built with a Docker container.

## Requirements

- Python 3.7
- Poetry package manager
- Cassandra database
- Docker

## Quick Start

1. Clone the repository and navigate to the project directory.
2. Install dependencies with `poetry install`.
3. Rename the `.env.example` file to `.env`.
4. Modify the environment variables in the `.env` file according to the desired configuration.
5. Start the Data Loader Microservice with `poetry run python app/main.py`.

## API

This microservice does not have an API.

## Database Tables

This microservice uses a Cassandra database. The tables it creates are:

- fds.allergies
- fds.diseases
- fds.symptoms
- fds.symptom_severity

## Docker

The Data Loader Microservice can be run as a Docker container with the following command:

```
docker-compose up -d data-loader
```

The microservice's configuration parameters are defined in the `docker-compose.yml` file.