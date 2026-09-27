id: proyectar-estancia
name: Proyectar estancia
version: 1
description: >-
  Integración PMS → front office (pms-fo, PoC ACL): lleva al front office del hotel una reserva tal como Opera la tiene — creada, cambiada o cancelada, venga del CRS o de la propia Opera. La relee de Opera y la manda al front office, que la ordena por la última modificación de Opera. Lo transitorio se reintenta.
steps:
  - id: start
    type: START
    name: Start
  - id: project-stay
    type: ACTION
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
