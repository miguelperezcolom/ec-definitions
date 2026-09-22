id: proyectar-cancelacion
name: Proyectar cancelación
version: 1
description: >-
  Integración CRS → PMS (PoC ACL). Cancela en Opera una reserva cancelada en el CRS, con el motivo traducido. Si
  la reserva todavía no está en Opera, la cancelación no se descarta: espera a que «Proyectar reserva» la grabe y
  entonces la cancela, para que el PMS conserve el registro (R37). La penalización en el folio queda fuera de la PoC.
steps:
  - id: start
    type: START
    name: Start
  - id: prepare
    type: ACTION
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
  - id: lock
    type: LOCK
    name: Bloquear la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: prepared
  - id: cancel-reservation
    type: ACTION
    name: Cancelar en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock
  - id: unlock
    type: UNLOCK
    name: Desbloquear la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: cancel-reservation
  - id: cancelled
    type: CHOICE
    name: ¿Cancelada?
    preconditions:
      - stepId: unlock
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
  - id: end
    type: END
    name: Cancelada
    preconditions:
      - stepId: cancelled
