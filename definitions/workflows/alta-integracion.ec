id: alta-integracion
name: Alta de integración
version: 1
description: >-
  Integración CRS → PMS (PoC ACL): el ciclo de vida de la integración de un hotel, del registro a la activación, por puertas. Cada paso lo hace integrations-service; cada espera se abre cuando ocurre lo que espera.
steps:
  - id: start
    type: START
    name: Start

  - id: verify-connectivity
    type: ACTION
    name: Verificar la conectividad con Opera
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: start
  - id: wait-connectivity
    type: WAIT_FOR_MESSAGE
    name: Esperar a una conexión que Opera acepte
    messageName: integration-connectivity-ok
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: verify-connectivity

  - id: contrast-catalogues
    type: ACTION
    name: Contrastar los catálogos de la propiedad y del CRS
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-connectivity
  - id: wait-configured
    type: WAIT_FOR_MESSAGE
    name: Esperar a que la propiedad esté configurada en Opera
    messageName: integration-property-configured
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: contrast-catalogues

  - id: request-mapping
    type: ACTION
    name: Pedir el mapeado del hotel
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-configured
  - id: wait-mapping
    type: WAIT_FOR_MESSAGE
    name: Esperar a que una persona apruebe el mapeado
    messageName: integration-mapping-approved
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: request-mapping

  - id: sync-partners
    type: ACTION
    name: Sincronizar los interlocutores de las reservas del hotel
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-mapping
  - id: wait-partners
    type: WAIT_FOR_MESSAGE
    name: Esperar a que sean perfiles en Opera
    messageName: integration-partners-synced
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: sync-partners

  - id: backfill-prepass
    type: ACTION
    name: Pasada previa del backfill
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-partners
  - id: wait-backfill-clear
    type: WAIT_FOR_MESSAGE
    name: Esperar a que no queden huecos
    messageName: integration-backfill-clear
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: backfill-prepass

  - id: start-backfill
    type: ACTION
    name: Iniciar el backfill (llegada más próxima primero)
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-backfill-clear
  - id: wait-window
    type: WAIT_FOR_MESSAGE
    name: Esperar a que cubra la ventana de activación
    messageName: integration-window-covered
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: start-backfill

  - id: await-activation
    type: ACTION
    name: Lista para activar
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-window
  - id: wait-activation
    type: WAIT_FOR_MESSAGE
    name: Esperar a que una persona la active
    messageName: integration-activation-requested
    correlationExpression: processKey
    timeout: P365D
    retries: 10000
    preconditions:
      - stepId: await-activation

  - id: activate
    type: ACTION
    name: Activar (el tráfico en tiempo real fluye)
    topic: integrations
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-activation
  - id: end
    type: END
    name: Activa
    preconditions:
      - stepId: activate
