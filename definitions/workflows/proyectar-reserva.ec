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

  # ── Grabar la reserva ───────────────────────────────────────────────────────
  # Leer la versión del UDF y escribir son dos llamadas a OHIP, sin escritura condicional. El
  # conector las serializa por reserva. El LOCK del motor sería el sitio (R18), pero en 2.18.0 falla
  # sobre PostgreSQL: su clave lleva un carácter NUL que PostgreSQL no admite en un texto.
  - id: upsert-reservation
    type: ACTION
    name: Grabar la reserva en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: profiled
  - id: written
    type: CHOICE
    name: ¿Grabada?
    preconditions:
      - stepId: upsert-reservation
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
  # ── El front office del hotel: la misma reserva, como estancia por llegar ────
  # Solo para los hoteles que tienen uno; para el resto el paso no hace nada. Si no responde, se
  # reintenta; nunca bloquea lo que ya está en Opera.
  - id: write-front-office
    type: ACTION
    name: Grabar la reserva en el front office
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: resolve-projection
  - id: end
    type: END
    name: Proyectada
    preconditions:
      - stepId: write-front-office
