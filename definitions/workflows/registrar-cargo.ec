id: registrar-cargo
name: Registrar cargo
version: 1
description: >-
  Integración front office → PMS (pms-fo): un cargo de recepción (late check-out, extra, consumo) se postea en el folio de la reserva en Opera, maestro del folio, para que su factura lo incluya. Un rechazo es una causa y el proceso espera.
steps:
  - id: start
    type: START
    name: Start

  # Un posteo en el folio es una escritura en la reserva de Opera: el mismo candado que toman el
  # check-in y el check-out lo ordena con ellos — va después del check-in y antes del check-out que
  # recepción hizo después. Se suelta antes de esperar a una causa.
  - id: lock-charge
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: post-charge
    type: ACTION
    task: post-charge
    name: Postear el cargo en el folio de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-charge
  - id: unlock-charge
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: post-charge
  - id: charge-done
    type: CHOICE
    name: ¿En el folio de Opera?
    preconditions:
      - stepId: unlock-charge
  - id: wait-charge
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: charge-done
        expression: chargeOutcome == 'WAIT'
  - id: relaunch-charge
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-charge
  - id: end-relaunched-charge
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-charge
  - id: end
    type: END
    name: En el folio de Opera
    preconditions:
      - stepId: charge-done
