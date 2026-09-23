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
  - id: cancel-reservation
    type: ACTION
    name: Cancelar en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: prepared
  - id: cancelled
    type: CHOICE
    name: ¿Cancelada?
    preconditions:
      - stepId: cancel-reservation
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
  # ── El front office del hotel: su estancia, cancelada ──────────────────────
  # Solo si el hotel tiene uno. Una estancia ya en casa no se cancela desde el CRS: es cosa de
  # recepción, y el paso termina igual.
  - id: cancel-front-office
    type: ACTION
    name: Cancelar la estancia en el front office
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: cancelled
  - id: end
    type: END
    name: Cancelada
    preconditions:
      - stepId: cancel-front-office
