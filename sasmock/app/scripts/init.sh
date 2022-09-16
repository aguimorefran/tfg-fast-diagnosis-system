#!/usr/bin/env sh

# if $RESET_DB.lower() == 'true' then drop $PEOPLE_TABLE from $CASSANDRA_KEYSPACE
if [ "$RESET_DB" = "true" ]; then
    echo "RESET_DB is set to true, dropping table...";
    cqsh -e "DROP TABLE $CASSANDRA_KEYSPACE.$PEOPLE_TABLE;"

# execute init.cql to create keyspace and table