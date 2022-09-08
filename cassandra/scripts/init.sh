#!/usr/bin/env sh

# cassandra:9042
until cqlsh cassandra 9042 -e "describe keyspaces"; do 
    sleep 5;
    echo "Waiting for cassandra...";
done

echo "Cassandra is up and running";
echo "Executing dropks.cql to drop keyspace";
cqlsh cassandra 9042 -f /scripts/dropks.cql
echo "Keyspaces after dropks.cql";
cqlsh cassandra 9042 -e "describe keyspaces";
echo "Executing init.cql to create keyspace";
cqlsh cassandra 9042 -f /scripts/init.cql