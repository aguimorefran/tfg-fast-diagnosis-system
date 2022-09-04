CREATE KEYSPACE fds WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'};
CREATE TABLE fds.symptoms (
    id int PRIMARY KEY,
    name text,
    precautions text,
    severity int
);
CREATE TABLE fds.diseases (
    id int PRIMARY KEY,
    name text,
    symptoms list<int>
);