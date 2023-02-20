CREATE KEYSPACE fds WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'};


CREATE TABLE fds.diseases (
    id uuid,
    name text,
    description text,
    symptoms set<uuid>,
    precautions set<uuid>,
    severity float,
    PRIMARY KEY (id)
);

CREATE TABLE fds.symptoms (
    id uuid,
    name text,
    severity float,
    PRIMARY KEY (id)
);

CREATE TABLE fds.precautions (
    id uuid,
    name text,
    PRIMARY KEY (id)
);