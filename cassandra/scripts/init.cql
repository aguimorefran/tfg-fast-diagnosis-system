CREATE KEYSPACE fds WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'};


CREATE TABLE fds.diseases (
    name text,
    description text,
    symptoms text,
    precautions text,
    severity int,
    PRIMARY KEY (name)
);

CREATE TABLE fds.symptoms (
    name text,
    severity int,
    PRIMARY KEY (name)
);

CREATE TABLE fds.precautions (
    name text,
    PRIMARY KEY (name)
);