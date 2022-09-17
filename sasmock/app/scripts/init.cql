CREATE TABLE fds.people IF NOT EXISTS (
    dni text PRIMARY KEY,
    nombre text,
    apellido1 text,
    apellido2 text,
    sexo text,
    fecha_nacimiento text,
    edad int,
    telefono int,
    email text,
    municipio text,
    provincia text,
    direccion text,
    direccion_numero int,
    codigo_postal int
);
