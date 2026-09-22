id: proyectar-reserva
name: Proyectar reserva
version: 1
description: >-
  Integración CRS → PMS (PoC ACL). Graba en Opera una reserva creada o modificada en el CRS: prepara todas las
  traducciones, asegura el perfil del huésped, graba la reserva por su localizador con la guarda de versión y
  anota en el CRS dónde quedó. Lo que no puede resolverse solo — un código sin equivalencia, un interlocutor que
  no está en el PMS, un rechazo de Opera — no falla: el proceso espera a que se resuelva la causa y entonces
  relanza una instancia nueva, que vuelve a leer la reserva. Lo transitorio se reintenta sin límite práctico.
steps:
  - id: start
    type: START
    name: Start

  # ── Preparar: local, no toca el PMS ─────────────────────────────────────────
  - id: prepare
    type: ACTION
    name: Preparar (resolver todas las traducciones)
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
    name: Relanzar (releer la reserva)
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

  # ── Perfil del huésped ──────────────────────────────────────────────────────
  - id: ensure-guest-profile
    type: ACTION
    name: Asegurar el perfil del huésped
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: prepared
  - id: profiled
    type: CHOICE
    name: ¿Perfil asegurado?
    preconditions:
      - stepId: ensure-guest-profile
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
    name: Relanzar (releer la reserva)
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

  # ── Grabar la reserva, serializado por reserva ──────────────────────────────
  # OHIP no tiene escritura condicional: leer la versión del UDF y escribir son dos llamadas. El LOCK
  # hace que dos procesos de la misma reserva no las intercalen, que es lo que el HLA pide del
  # compare-and-set (R18).
  - id: lock
    type: LOCK
    name: Bloquear la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: profiled
  - id: upsert-reservation
    type: ACTION
    name: Grabar la reserva en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock
  - id: unlock
    type: UNLOCK
    name: Desbloquear la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: upsert-reservation
  - id: written
    type: CHOICE
    name: ¿Grabada?
    preconditions:
      - stepId: unlock
  - id: wait-write
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: written
        expression: writeOutcome == 'WAIT'
  - id: relaunch-write
    type: ACTION
    name: Relanzar (releer la reserva)
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-write
  - id: end-relaunched-write
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-write

  # ── Anotar en el CRS y liberar las cancelaciones que esperaban ──────────────
  - id: annotate-pms-reference
    type: ACTION
    name: Anotar la referencia del PMS en el CRS
    topic: crs-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: written
  - id: resolve-projection
    type: ACTION
    name: Liberar lo que esperaba a que llegase al PMS
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: annotate-pms-reference
  - id: end
    type: END
    name: Proyectada
    preconditions:
      - stepId: resolve-projection
