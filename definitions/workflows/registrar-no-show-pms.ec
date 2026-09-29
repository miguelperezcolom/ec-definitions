id: registrar-no-show-pms
name: Registrar no-show en el PMS
version: 1
description: >-
  Integración front office → PMS → CRS (HLA F006): nadie llegó. Opera lo anota en la reserva y la integración crs-pms lo sube al CRS, que aplica su cargo (registrar-no-show); la cancelación baja como siempre.
steps:
  - id: start
    type: START
    name: Start
  - id: lock-no-show
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: record-no-show
    type: ACTION
    task: record-no-show
    name: Anotar el no-show en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-no-show
  - id: unlock-no-show
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: record-no-show
  - id: recorded
    type: CHOICE
    name: ¿Anotado?
    preconditions:
      - stepId: unlock-no-show
  - id: wait-no-show
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: recorded
        expression: noShowOutcome == 'WAIT'
  - id: relaunch-no-show
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-no-show
  - id: end-relaunched-no-show
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-no-show
  # Al CRS, por su integración: arranca «registrar-no-show», que cancela la reserva como no-show con
  # su cargo. Una vez por reserva: el mismo aviso dos veces es un solo no-show.
  - id: report-no-show
    type: ACTION
    task: report-no-show
    name: Subir el no-show al CRS
    topic: crs-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: recorded
  - id: end
    type: END
    name: Registrado
    preconditions:
      - stepId: report-no-show
