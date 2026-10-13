id: asignar-empresa
name: Asignar empresa
version: 1
description: >-
  Integración front office → PMS (pms-fo): la empresa a la que se factura la estancia se pone en la reserva de Opera —su perfil y la ventana 2 del folio— o se quita. Un rechazo es una causa y el proceso espera.
steps:
  - id: start
    type: START
    name: Start

  # Cambiar la empresa es una escritura en la reserva de Opera: el mismo candado que toman el check-in,
  # el check-out y los cargos la ordena con ellos, y con otro cambio de empresa de la misma estancia
  # (gana el último que hizo recepción). Se suelta antes de esperar a una causa.
  - id: lock-company
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start
  - id: assign-company
    type: ACTION
    task: assign-company
    name: Poner la empresa en la reserva de Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-company
  - id: unlock-company
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: assign-company
  - id: company-done
    type: CHOICE
    name: ¿En la reserva de Opera?
    preconditions:
      - stepId: unlock-company
  - id: wait-company
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: company-done
        expression: companyOutcome == 'WAIT'
  - id: relaunch-company
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-company
  - id: end-relaunched-company
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-company
  - id: end
    type: END
    name: En la reserva de Opera
    preconditions:
      - stepId: company-done
