id: proyectar-cancelacion
name: Proyectar cancelación
version: 1
description: >-
  Integración CRS → PMS (PoC ACL): cancela en Opera una reserva cancelada en el CRS. Si aún no está en Opera, espera a que se proyecte y entonces la cancela (R37).
steps:
  - id: start
    type: START
    name: Start
  - id: prepare
    type: ACTION
    task: prepare-cancellation
    name: Preparar (hotel y motivo)
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: start
  - id: prepared
    type: CHOICE
    name: ¿Falta algo?
    preconditions:
      - stepId: prepare
  - id: wait-prepare
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: prepared
        expression: prepareOutcome == 'WAIT'
  - id: relaunch-prepare
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-prepare
  - id: end-relaunched-prepare
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-prepare
  # Leer la reserva en Opera y cancelarla, serializado por reserva con el mismo candado que
  # «proyectar-reserva» toma para grabarla (R18). Solo alrededor de la escritura: si la reserva aún no
  # está en Opera, se espera a que llegue sin retener el candado que su proyección necesita.
  - id: lock-cancel
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: prepared
  - id: cancel-reservation
    type: ACTION
    task: cancel-reservation
    name: Cancelar en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-cancel
  - id: unlock-cancel
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: cancel-reservation
  - id: cancelled
    type: CHOICE
    name: ¿Cancelada?
    preconditions:
      - stepId: unlock-cancel
  - id: wait-cancel
    type: WAIT_FOR_MESSAGE
    name: Esperar (p. ej. a que la reserva llegue al PMS)
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: cancelled
        expression: writeOutcome == 'WAIT'
  - id: relaunch-cancel
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-cancel
  - id: end-relaunched-cancel
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-cancel
  # La estancia del front office la cancela la integración pms-fo, leyendo Opera: aquí no.
  - id: end
    type: END
    name: Cancelada
    preconditions:
      - stepId: cancelled
