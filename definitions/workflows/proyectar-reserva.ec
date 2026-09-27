id: proyectar-reserva
name: Proyectar reserva
version: 1
description: >-
  Integración CRS → PMS (PoC ACL): graba en Opera una reserva creada o modificada en el CRS. Lo que no se resuelve solo espera a su causa y relanza una instancia nueva; lo transitorio se reintenta.
steps:
  - id: start
    type: START
    name: Start

  # ── Preparar: local, no toca el PMS ─────────────────────────────────────────
  - id: prepare
    type: ACTION
    task: prepare-reservation
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
    task: relaunch-process
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
    task: ensure-guest-profile
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
    task: relaunch-process
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

  # ── Grabar la reserva ───────────────────────────────────────────────────────
  # Leer la versión del UDF y escribir son dos llamadas a OHIP, sin escritura condicional: el LOCK
  # del motor las serializa por reserva (R18), también frente a «proyectar-cancelacion», que toma el
  # mismo candado. Solo alrededor de la escritura: un proceso que espera a sus causas no lo retiene.
  - id: lock-write
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: profiled
  - id: upsert-reservation
    type: ACTION
    task: upsert-reservation
    name: Grabar la reserva en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-write
  - id: unlock-write
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: upsert-reservation
  - id: written
    type: CHOICE
    name: ¿Grabada?
    preconditions:
      - stepId: unlock-write
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
    task: relaunch-process
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
    task: annotate-pms-reference
    name: Anotar la referencia del PMS en el CRS
    topic: crs-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: written
  - id: resolve-projection
    type: ACTION
    task: resolve-projection
    name: Liberar lo que esperaba a que llegase al PMS
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: annotate-pms-reference
  # El front office ya no se graba desde aquí: cuelga del PMS (integración pms-fo). Al grabar en
  # Opera, el conector publica pms-reservations y la integración pms-fo proyecta la estancia desde lo
  # que Opera tiene («proyectar-estancia»).
  - id: end
    type: END
    name: Proyectada
    preconditions:
      - stepId: resolve-projection
