# Dataloader

Este microservicio es un microservicio diseñado para cargar datos en una base de datos utilizando una interfaz de línea de comandos (CLI). El objetivo principal es proporcionar una forma sencilla y eficiente de cargar grandes cantidades de datos en una base de datos de manera automática.

## Estructura del microservicio

El microservicio "dataloader" está estructurado de la siguiente manera:

- Archivo `Dockerfile`: Este archivo contiene las instrucciones necesarias para construir una imagen Docker del microservicio.
- Archivo `entrypoint.sh`: Este archivo es el punto de entrada del microservicio y se encarga de ejecutar el script principal.
- Archivo `main.py`: Este archivo contiene el código principal del microservicio, incluyendo la lógica para cargar los datos en la base de datos.

## Configuración y ejecución

Para ejecutar el microservicio, se deben seguir los siguientes pasos:

1. Construir la imagen Docker utilizando el archivo `Dockerfile`. Esto puede hacerse ejecutando el siguiente comando en la terminal:

```
docker build -t dataloader .
```

2. Una vez que la imagen se haya construido, se puede ejecutar el microservicio utilizando el siguiente comando:

```
docker run dataloader
```

El microservicio se ejecutará y comenzará a cargar los datos en la base de datos configurada.

## Requisitos

El microservicio requiere tener Docker instalado en el sistema para poder construir y ejecutar la imagen Docker del microservicio. Además, se debe tener acceso a una base de datos compatible con el microservicio, y se deben proporcionar los datos a cargar en un formato adecuado.
