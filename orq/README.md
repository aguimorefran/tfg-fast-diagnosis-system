# Orquestador 

## Descripción

El proyecto `orq` es un microservicio diseñado para proporcionar una orquestación a medida para aplicaciones. Se basa en una estructura simple que permite ejecutar múltiples aplicaciones y coordinarlas de manera eficiente.

## Estructura del proyecto

El proyecto `orq` consta de los siguientes archivos:

1. `Dockerfile`: Archivo utilizado para construir la imagen de Docker del microservicio.
2. `app/main.py`: Archivo principal del microservicio que contiene la lógica de orquestación de las aplicaciones.
3. `app/__init__.py`: Archivo de inicialización para el paquete `app`.

## Ejecución

A continuación se describen los pasos para ejecutar el microservicio `orq`:

1. Clona el repositorio del proyecto `orq`.
2. En la línea de comandos, navega hasta el directorio `orq`.
3. Ejecuta el comando `docker build -t orq .` para construir la imagen de Docker.
4. Una vez construida la imagen, ejecuta el comando `docker run -d -p 8000:8000 orq` para iniciar el contenedor Docker.
5. El microservicio `orq` estará ahora disponible en `http://localhost:8000`.

## Información adicional

- El microservicio `orq` se encuentra implementado en Python utilizando el framework Flask.
- Ofrece una interfaz RESTful para recibir y procesar solicitudes de orquestación.
- Se recomienda tener Docker instalado para la ejecución del proyecto.

Para más información y detalles sobre el uso y configuración del microservicio `orq`, refiérase a la documentación proporcionada en el repositorio del proyecto.