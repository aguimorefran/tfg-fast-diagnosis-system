# FDS Cassandra Setup Microservice

This microservice sets up the Cassandra keyspace and tables required for the FDS application to run.

## Features
- Creates the necessary Cassandra keyspace and tables for the FDS application.
- Handles erasing data if needed.

## Requirements
- Python 3.6 or higher
- Poetry dependency manager

## Quick Start
1. Clone the repository containing the microservice.
2. Install dependencies using the `poetry install` command.
3. Run the `init.sh` script to create the keyspace and tables: `./cassandra/scripts/init.sh`
4. The Cassandra keyspace and tables required for the FDS application should now be set up.

## API
This microservice does not expose any API endpoints.

For more information on the deployment of this microservice, see the `docker-compose.yml` file.
