id: registrar-cobro
name: Registrar cobro
version: 1
description: >-
  Integración front office → PMS (pms-fo): un cobro de la caja de recepción (pago o anticipo) se postea en el folio de la reserva en Opera, maestro del folio, para que su saldo sea lo que queda por cobrar. Un rechazo es una causa y el proceso espera.
steps:
  - id: start
    type: START
    name: Start

  # Un cobro en el folio es una escritura en la reserva de Opera: el mismo candado que toman el
  # check-in y el check-out lo ordena con ellos — va después del check-in y antes del check-out que
  # recepción hizo después. Se suelta antes de esperar a una causa.
  - id: lock-payment
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: post-payment
    type: ACTION
    task: post-payment
    name: Postear el cobro en el folio de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-payment
  - id: unlock-payment
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: post-payment
  - id: payment-done
    type: CHOICE
    name: ¿En el folio de Opera?
    preconditions:
      - stepId: unlock-payment
  - id: wait-payment
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: payment-done
        expression: paymentOutcome == 'WAIT'
  - id: relaunch-payment
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-payment
  - id: end-relaunched-payment
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-payment
  - id: end
    type: END
    name: En el folio de Opera
    preconditions:
      - stepId: payment-done
