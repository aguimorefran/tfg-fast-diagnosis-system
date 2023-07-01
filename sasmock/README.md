# SASMock

Este proyecto consiste en un microservicio basado en SAS (Software as a Service) que provee una simulación de datos para pruebas y desarrollo. 

## Estructura del proyecto

El proyecto está estructurado de la siguiente manera:

- `Dockerfile`: Archivo de configuración para construir la imagen de Docker del microservicio.
- `app/main.py`: Archivo principal que contiene el código del microservicio.

## Requisitos previos

Antes de ejecutar el proyecto, asegúrese de tener instalado Docker en su sistema.

## Ejecutando el proyecto

Para ejecutar el microservicio, siga los siguientes pasos:

1. Clone el repositorio en su máquina local.

2. Navegue hasta el directorio raíz del proyecto.

3. Ejecute el siguiente comando para construir la imagen de Docker:

```
docker build -t sasmock .
```

4. Una vez finalizada la construcción, ejecute el siguiente comando para iniciar el contenedor:

```
docker run -p 8000:8000 sasmock
```

5. Ahora podrá acceder al microservicio a través de su navegador o utilizando herramientas como cURL. El microservicio estará disponible en `http://localhost:8000`.

## Información adicional

- En el archivo `Dockerfile` se especifican las dependencias necesarias para la ejecución del microservicio.

- El archivo `main.py` contiene la lógica del microservicio y define los puntos finales para interactuar con él.

- Este proyecto está destinado a ser utilizado como un servicio de simulación de datos para pruebas y desarrollo, y puede ser integrado con otros servicios para completar una aplicación más amplia.

- Para obtener más información sobre el funcionamiento y la configuración del microservicio, consulte la documentación en línea proporcionada en el repositorio.