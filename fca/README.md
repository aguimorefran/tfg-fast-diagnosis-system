# Motor FCA

Este proyecto es un microservicio implementado en lenguaje R y diseñado para el análisis y procesamiento de datos utilizando el algoritmo Formal Concept Analysis (FCA). Proporciona una API que permite la carga de datos, ejecución del algoritmo FCA y acceso a los resultados obtenidos.

## Requisitos previos

Para poder ejecutar este proyecto es necesario tener instalado R y las siguientes dependencias:

- R version >= 3.5

## Configuración

Antes de ejecutar el microservicio, es necesario asegurarse de que se cumplen los siguientes requisitos:

1. Asegurarse de tener acceso a los datos que se desean analizar y que se encuentran en un formato compatible (puede consultarse más información sobre el formato de datos en la documentación adjunta).
2. Actualizar el archivo 'benchmark_testing.r' con las configuraciones específicas del análisis que se desea realizar, incluyendo la ubicación del archivo de datos a utilizar y los parámetros de configuración para el algoritmo FCA.

## Ejecución

Una vez configurado correctamente el proyecto, para ejecutarlo se deben seguir los siguientes pasos:

1. Situarse en la carpeta 'fca/' dentro del repositorio clonado.
2. Ejecutar el comando `Rscript run_api.r` para iniciar la API del microservicio.

## Uso de la API

La API proporciona los siguientes endpoints:

- `/load_data`: Permite cargar los datos para su posterior análisis.
- `/run_fca`: Ejecuta el algoritmo FCA sobre los datos cargados.
- `/get_results`: Obtiene los resultados obtenidos tras la ejecución del algoritmo FCA.

Es importante tener en cuenta que los endpoints `/run_fca` y `/get_results` deben ser utilizados en secuencia, una vez que los datos hayan sido cargados correctamente.
