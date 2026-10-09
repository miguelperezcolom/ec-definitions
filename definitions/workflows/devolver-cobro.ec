id: devolver-cobro
name: Devolver cobro
version: 1
description: >-
  Integración front office → PMS (pms-fo): un cobro que recepción devolvió se devuelve en el folio de Opera (el mismo pago en negativo, contra el original). Si el cobro aún no está en Opera, espera a que llegue; un rechazo es una causa.
steps:
  - id: start
    type: START
    name: Start

  # Una devolución en el folio es una escritura en la reserva de Opera: el mismo candado que toman el
  # check-in y el check-out lo ordena con ellos — va después del check-in y antes del check-out que
  # recepción hizo después. Se suelta antes de esperar a una causa.
  - id: lock-refund
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: refund-payment
    type: ACTION
    task: refund-payment
    name: Devolver el cobro en el folio de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-refund
  - id: unlock-refund
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: refund-payment
  - id: refund-done
    type: CHOICE
    name: ¿En el folio de Opera?
    preconditions:
      - stepId: unlock-refund
  - id: wait-refund
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: refund-done
        expression: refundOutcome == 'WAIT'
  - id: relaunch-refund
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-refund
  - id: end-relaunched-refund
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-refund
  - id: end
    type: END
    name: En el folio de Opera
    preconditions:
      - stepId: refund-done
