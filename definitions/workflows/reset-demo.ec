id: reset-demo
name: Resetear la demo
version: 1
description: >-
  La demo vuelve a cero, como deploy/demo/zero.sh pero sin parar nada: una persona lo confirma; el
  CRS deja de admitir reservas; cada servicio se vacía a sí mismo (en paralelo); Salesforce pierde
  sus contactos y Cases; Opera recibe un contexto nuevo (nunca se limpia); el motor borra los
  procesos menos éste; el CRS vuelve a admitir reservas; opcionalmente se siembran las reservas
  demo; se comprueba la salud y queda un aviso en la bandeja. Lo lanza la página Demo del plano de
  control. Un paso que falla tres veces deja el proceso en error: «Reintentar desde el fallo».
steps:
  - id: start
    type: START
    name: Start

  # Sólo un administrador (ai-admin): el formulario lo exige, y la bandeja sólo se lo muestra a ellos.
  - id: confirm
    type: USER_TASK
    name: Confirmar el reset (borra también Salesforce)
    formId: confirmar-reset-demo
    topic: forms
    preconditions:
      - stepId: start
  - id: confirmed
    type: CHOICE
    name: ¿Confirmado?
    preconditions:
      - stepId: confirm
  - id: not-confirmed
    type: END
    name: No confirmado, nada cambió
    preconditions:
      - stepId: confirmed

  - id: pause-intake
    type: ACTION
    task: pause-intake
    name: Pausar la entrada de reservas en el CRS
    topic: booking
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: confirmed
        expression: confirmado == 'true'

  # Cada servicio se vacía a sí mismo: la misma tarea, reset, en el topic de cada uno.
  - id: reset-services
    type: FORK
    name: Cada servicio, a cero
    preconditions:
      - stepId: pause-intake

  - id: reset-booking
    type: ACTION
    task: reset
    name: "A cero: el CRS: reservas y tarifas creadas"
    topic: booking
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-erp
    type: ACTION
    task: reset
    name: "A cero: el ERP: su outbox (los interlocutores se quedan)"
    topic: erp
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-front-office
    type: ACTION
    task: reset
    name: "A cero: el front office: huéspedes, estancias, folios, catálogo del PMS; habitaciones libres"
    topic: front-office
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-notices
    type: ACTION
    task: reset
    name: "A cero: los avisos de recepción"
    topic: notices-tasks
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-crs-integration
    type: ACTION
    task: reset
    name: "A cero: crs-integration: su inbox y outbox"
    topic: crs-integration
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-mapping
    type: ACTION
    task: reset
    name: "A cero: el mapeo: causas, diccionario, perfiles, esperas"
    topic: mapping
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-customer-mdm
    type: ACTION
    task: reset
    name: "A cero: el MDM: clientes, fuentes, xrefs, consolidaciones, peticiones de cambio"
    topic: customer-mdm
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-integrations
    type: ACTION
    task: reset
    name: "A cero: las integraciones crs-pms y pms-fo (y su cursor)"
    topic: integrations
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-communication
    type: ACTION
    task: reset
    name: "A cero: la bandeja y las notificaciones"
    topic: communication
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: reset-audit
    type: ACTION
    task: reset
    name: "A cero: la auditoría (menos la de la propia demo)"
    topic: audit-tasks
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: reset-services

  - id: services-reset
    type: JOIN
    name: Todos los servicios a cero
    joinType: AND
    preconditionStepIds: [reset-booking, reset-erp, reset-front-office, reset-notices, reset-crs-integration, reset-mapping, reset-customer-mdm, reset-integrations, reset-communication, reset-audit]

  - id: clean-salesforce
    type: ACTION
    task: clean-salesforce
    name: Borrar los contactos y Cases de Salesforce
    topic: customer-mdm
    timeout: PT10M
    retries: 3
    preconditions:
      - stepId: services-reset
  - id: new-opera-context
    type: ACTION
    task: new-opera-context
    name: Un contexto nuevo de Opera (Opera no se limpia)
    topic: pms-integration
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: clean-salesforce

  # El último paso de datos: borra los procesos de todo lo anterior, menos éste.
  - id: purge-engine
    type: ACTION
    task: purge-engine
    name: El motor a cero (menos este proceso)
    topic: integrations
    timeout: PT5M
    retries: 3
    preconditions:
      - stepId: new-opera-context
  - id: resume-intake
    type: ACTION
    task: resume-intake
    name: Reanudar la entrada de reservas en el CRS
    topic: booking
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: purge-engine

  - id: seed
    type: CHOICE
    name: ¿Sembrar las reservas demo?
    preconditions:
      - stepId: resume-intake
  - id: seed-demo-bookings
    type: ACTION
    task: seed-demo-bookings
    name: Sembrar las reservas demo de MRU01
    topic: booking
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: seed
        expression: sembrar == 'true'
  - id: seeded
    type: JOIN
    name: Sembrada o no
    joinType: XOR
    preconditionStepIds: [seed-demo-bookings, seed]

  - id: check-health
    type: ACTION
    task: check-demo-health
    name: Comprobar la salud de la demo
    topic: integrations
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: seeded
  - id: notify-result
    type: ACTION
    task: notify-reset-result
    name: Avisar del resultado en la bandeja
    topic: integrations
    timeout: PT2M
    retries: 3
    preconditions:
      - stepId: check-health
  - id: end
    type: END
    name: La demo está a cero
    preconditions:
      - stepId: notify-result
