# Interfaz de usuario

Este es el frontend de la aplicación web. Su principal función es gestionar la presentación y la interacción con el usuario.

## Estructura del proyecto

- `Dockerfile`: Archivo utilizado para construir la imagen Docker del microservicio.

## Ejecución

Para ejecutar este microservicio, se recomienda seguir los siguientes pasos:

1. Clonar el repositorio en local.
2. En la carpeta raíz del proyecto, ejecutar el comando `docker build -t frontend .` para construir la imagen Docker.
3. A continuación, ejecutar el comando `docker run -p 8080:8080 frontend` para iniciar el microservicio.
4. Acceder a la aplicación web a través de la URL `http://localhost:8080`.

## Información adicional

- El microservicio está diseñado para funcionar de forma independiente, pero se comunica con otros servicios a través de API REST.
- Es posible personalizar la apariencia y el comportamiento de la aplicación web modificando los archivos ubicados en la carpeta `src`.
- Se recomienda revisar la documentación proporcionada para obtener más detalles sobre la utilización de este microservicio.