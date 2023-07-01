![fds-logo](fds-logo250.png)

# FDS: Fast Diagnosis System

Aplicación de diagnóstico rapido para la detección de enfermedades en personas. Nacido de la necesidad de diagnosticar enfermedades en personas de forma rápida y eficiente, FDS es una aplicación que permite a los usuarios diagnosticar enfermedades de forma rápida y eficiente, con el fin de que puedan tomar las medidas necesarias para su tratamiento.

Basada en FCA, es capaz de entrenarse con un conjunto de datos de enfermedades y síntomas, para luego poder diagnosticar enfermedades en base a los síntomas que el usuario ingrese y sus datos personales.

## Componentes

### Dataloader

Microservicio FastAPI encargado de cargar los datos de entrenamiento en la base de datos y de generar tablas.
[README](dataloader/README.md)

### Motor FCA

Microservicio en R encargado de realizar el entrenamiento de la aplicación, y brindar los diagnósticos. Expone una API REST.
[README](fca/README.md)

### Interfaz Web

Interfaz web en ReactJS que permite a los usuarios interactuar con la aplicación.
[README](front/README.md)

### Orquestador

Microservicio en FastAPI que sirve como orquestador de los demás microservicios. Sirve como backend de la interfaz web.

[README](orq/README.md)

### SASMock

Microservicio en FastAPI que sirve como mock del Servicio Andaluz de Salud. Sirve datos falsos demográficos para la aplicación.

[README](sasmock/README.md)