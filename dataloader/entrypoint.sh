#!/bin/bash

until cqlsh -u cassandra -p cassandra cassandra 9042 -e 'describe cluster'; do
  echo "Cassandra no está disponible - durmiendo"
  sleep 1
done

python main.py