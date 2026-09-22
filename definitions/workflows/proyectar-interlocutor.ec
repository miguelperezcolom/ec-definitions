id: proyectar-interlocutor
name: Proyectar interlocutor
version: 1
description: >-
  Integración CRS → PMS (PoC ACL). Asegura en Opera el perfil de un interlocutor del maestro — agencia,
  turoperador, empresa — y registra a qué perfil corresponde, lo que reanuda las reservas que esperaban por él.
  Un perfil es de cadena en Opera: una vez, no una por hotel (R12).
steps:
  - id: start
    type: START
    name: Start
  - id: prepare
    type: ACTION
    name: Preparar (tipo de perfil)
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
  - id: ensure-partner-profile
    type: ACTION
    name: Asegurar el perfil en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: prepared
  - id: profiled
    type: CHOICE
    name: ¿Perfil asegurado?
    preconditions:
      - stepId: ensure-partner-profile
  - id: wait-profile
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: profiled
        expression: profileOutcome == 'WAIT'
  - id: relaunch-profile
    type: ACTION
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-profile
  - id: end-relaunched-profile
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-profile
  - id: record-partner-profile
    type: ACTION
    name: Registrar la correspondencia
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: profiled
  - id: end
    type: END
    name: Proyectado
    preconditions:
      - stepId: record-partner-profile
