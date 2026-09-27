id: proyectar-estancia
name: Proyectar estancia
version: 1
description: >-
  Integración PMS → front office (pms-fo): relee de Opera una reserva — del CRS o nacida en Opera — y la graba en el front office como estancia, ordenada por la última modificación de Opera.
steps:
  - id: start
    type: START
    name: Start
  - id: project-stay
    type: ACTION
    task: project-stay
    name: Leer la reserva de Opera y grabarla como estancia
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: start
  - id: end
    type: END
    name: Proyectada
    preconditions:
      - stepId: project-stay
