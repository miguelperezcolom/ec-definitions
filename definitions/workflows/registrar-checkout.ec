id: registrar-checkout
name: Registrar check-out
version: 1
description: >-
  Integración front office → PMS (pms-fo): la recepción hizo el check-out; Opera lo registra con el cajero de la integración y su factura llega al front office. Un rechazo es una causa y el proceso espera.
steps:
  - id: start
    type: START
    name: Start
  - id: lock-checkout
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: check-out-reservation
    type: ACTION
    task: check-out-reservation
    name: Hacer el check-out en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-checkout
  - id: unlock-checkout
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: check-out-reservation
  - id: checked-out
    type: CHOICE
    name: ¿Salida registrada?
    preconditions:
      - stepId: unlock-checkout
  - id: wait-checkout
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: checked-out
        expression: checkOutOutcome == 'WAIT'
  - id: relaunch-checkout
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-checkout
  - id: end-relaunched-checkout
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-checkout
  # La factura es del PMS: se lee de Opera (y se genera su documento, con el cajero) y va al front
  # office. Fuera del candado: no toca la reserva.
  - id: fetch-invoice
    type: ACTION
    task: fetch-invoice
    name: Recuperar la factura de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: checked-out
  - id: end
    type: END
    name: Salida registrada
    preconditions:
      - stepId: fetch-invoice
