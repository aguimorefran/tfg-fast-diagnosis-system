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

CREATE TABLE fds.people (
    dni text PRIMARY KEY,
    nombre text,
    apellido1 text,
    apellido2 text,
    sexo text,
    fecha_nacimiento timestamp,
    edad int,
    telefono int,
    email text,
    municipio text,
    provincia text,
    direccion text,
    direccion_numero int,
    codigo_postal int
);

CREATE TABLE fds.medical_history (
    dni text PRIMARY KEY,
    cuidador_dni text,
    cuidador_telefono int,
    cuidador_nombre text,
    alergias text,
    vacunaciones text,
    problemas_y_episodios_activos text,
    recomendaciones text,
    tratamientos text,
    enfermedades text
);