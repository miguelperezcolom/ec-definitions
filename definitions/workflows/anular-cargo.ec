id: anular-cargo
name: Anular cargo
version: 1
description: >-
  Integración front office → PMS (pms-fo): un cargo que recepción anuló se anula en el folio de Opera (el mismo importe en negativo). Si el cargo aún no está en Opera, espera a que llegue; un rechazo es una causa.
steps:
  - id: start
    type: START
    name: Start

  # Un posteo en el folio es una escritura en la reserva de Opera: el mismo candado que toman el
  # check-in y el check-out lo ordena con ellos — va después del check-in y antes del check-out que
  # recepción hizo después. Se suelta antes de esperar a una causa.
  - id: lock-reversal
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: reverse-charge
    type: ACTION
    task: reverse-charge
    name: Anular el cargo en el folio de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-reversal
  - id: unlock-reversal
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: reverse-charge
  - id: reversal-done
    type: CHOICE
    name: ¿En el folio de Opera?
    preconditions:
      - stepId: unlock-reversal
  - id: wait-reversal
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: reversal-done
        expression: reversalOutcome == 'WAIT'
  - id: relaunch-reversal
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-reversal
  - id: end-relaunched-reversal
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-reversal
  - id: end
    type: END
    name: En el folio de Opera
    preconditions:
      - stepId: reversal-done
