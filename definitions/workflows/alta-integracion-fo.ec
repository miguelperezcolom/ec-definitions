id: alta-integracion-fo
name: Alta de integración PMS → front office
version: 1
description: >-
  Integración PMS → front office (pms-fo): el alta, por puertas — conexión con Opera y el front office, catálogo del PMS en el front office, backfill y activación. Cada paso lo hace integrations-service.
steps:
  - id: start
    type: START
    name: Start

  - id: fo-verify-connectivity
    type: ACTION
    task: fo-verify-connectivity
    name: Verificar la conexión con Opera y con el front office
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: start
  - id: wait-connectivity
    type: WAIT_FOR_MESSAGE
    name: Esperar a que ambos respondan
    messageName: fo-integration-connectivity-ok
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: fo-verify-connectivity

  - id: fo-sync-catalogue
    type: ACTION
    task: fo-sync-catalogue
    name: Llevar el catálogo del PMS al front office
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-connectivity
  - id: wait-catalogue
    type: WAIT_FOR_MESSAGE
    name: Esperar a que el front office lo tenga
    messageName: fo-integration-catalogue-synced
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: fo-sync-catalogue

  - id: fo-start-backfill
    type: ACTION
    task: fo-start-backfill
    name: Iniciar el backfill (las reservas de Opera de la ventana)
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-catalogue
  - id: wait-backfill
    type: WAIT_FOR_MESSAGE
    name: Esperar a que termine
    messageName: fo-integration-backfill-done
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: fo-start-backfill

  - id: fo-await-activation
    type: ACTION
    task: fo-await-activation
    name: Lista para activar
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-backfill
  - id: wait-activation
    type: WAIT_FOR_MESSAGE
    name: Esperar a que una persona la active
    messageName: fo-integration-activation-requested
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: fo-await-activation

  - id: fo-activate
    type: ACTION
    task: fo-activate
    name: Activar (los cambios de Opera fluyen al front office)
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-activation
  - id: end
    type: END
    name: Activa
    preconditions:
      - stepId: fo-activate
