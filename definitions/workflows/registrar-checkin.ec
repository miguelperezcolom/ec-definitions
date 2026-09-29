id: registrar-checkin
name: Registrar check-in
version: 1
description: >-
  Integración front office → PMS (pms-fo): la recepción hizo el check-in y Opera, maestro de la estancia, lo registra (habitación y check-in). Un rechazo de Opera es una causa y el proceso espera; lo transitorio se reintenta.
steps:
  - id: start
    type: START
    name: Start

  # Asignar la habitación y hacer el check-in son escrituras en la reserva de Opera: el mismo candado
  # que toman «proyectar-reserva» y «proyectar-cancelacion» las serializa con cualquier otro cambio de
  # la reserva. Se suelta antes de esperar a una causa.
  - id: lock-checkin
    type: LOCK
    name: Tomar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: start

  # ── La habitación ───────────────────────────────────────────────────────────
  - id: assign-room
    type: ACTION
    task: assign-room
    name: Asignar la habitación en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: lock-checkin
  - id: room-assigned
    type: CHOICE
    name: ¿Habitación asignada?
    preconditions:
      - stepId: assign-room
  - id: unlock-room
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: room-assigned
        expression: roomOutcome == 'WAIT'
  - id: wait-room
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: unlock-room
  - id: relaunch-room
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-room
  - id: end-relaunched-room
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-room

  # ── El check-in ─────────────────────────────────────────────────────────────
  - id: check-in-reservation
    type: ACTION
    task: check-in-reservation
    name: Hacer el check-in en Opera
    topic: pms-integration
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: room-assigned
  - id: unlock-checkin
    type: UNLOCK
    name: Soltar el candado de la reserva
    lockName: reservation
    lockKey: hotelCode + '/' + locator
    preconditions:
      - stepId: check-in-reservation
  - id: checked-in
    type: CHOICE
    name: ¿En casa?
    preconditions:
      - stepId: unlock-checkin
  - id: wait-checkin
    type: WAIT_FOR_MESSAGE
    name: Esperar a que se resuelvan las causas
    messageName: causes-resolved
    correlationExpression: processKey
    timeout: P30D
    retries: 10000
    preconditions:
      - stepId: checked-in
        expression: checkInOutcome == 'WAIT'
  - id: relaunch-checkin
    type: ACTION
    task: relaunch-process
    name: Relanzar
    topic: mapping
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: wait-checkin
  - id: end-relaunched-checkin
    type: END
    name: Relanzado
    preconditions:
      - stepId: relaunch-checkin
  # «En casa» vuelve al front office por la proyección de la estancia: al hacer el check-in, el
  # conector publica pms-reservations y la integración pms-fo relee la reserva de Opera.
  - id: end
    type: END
    name: En casa
    preconditions:
      - stepId: checked-in
