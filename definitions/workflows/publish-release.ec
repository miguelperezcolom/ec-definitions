# Publicación de una release del website (ADR-0049, ADR-0051).
#
# Lo arranca el control-plane (caso de uso Publish) con businessKey = id de la release y las
# variables releaseId, requestedBy y canaryPercent. Los pasos ACTION los ejecuta el worker del
# publisher por el topic publication-tasks; él mismo notifica cada cambio de estado al control-plane
# (POST /api/callbacks/releases/{id}/progress), así el motor no guarda credenciales del control-plane.
#
#   construir (sin activar) → verificar → esperar aprobación (USER_TASK, la completa el
#   control-plane con approved/approver/comment) → canary → observar → promocionar o deshacer
#
# Mientras se observa, un humano puede forzar el resultado con el mensaje canary-override
# (forcedAction: promote | rollback; forcedBy). Si no llega, al vencer se evalúan las métricas.
#
# Ante un fallo definitivo (build, verificación, promoción…) se compensa: se anula el canary si
# llegó a empezar y se notifica FAILED al control-plane.
id: publish-release
name: Publicar una release del website
version: 1
steps:
  - id: start
    type: START
    name: Inicio

  - id: notify-building
    type: ACTION
    topic: publication-tasks
    name: Notificar «construyendo»
    preconditionStepId: start
    retries: 3
    compensable: true
    compensationStepId: notify-failed

  - id: build
    type: ACTION
    topic: publication-tasks
    name: Construir la release sin activarla
    preconditionStepId: notify-building
    timeout: PT30M

  - id: verify
    type: ACTION
    topic: publication-tasks
    name: Verificar (smoke y regresión visual)
    preconditionStepId: build
    timeout: PT20M

  - id: notify-awaiting
    type: ACTION
    topic: publication-tasks
    name: Notificar «pendiente de aprobación»
    preconditionStepId: verify
    retries: 3

  - id: approval
    type: USER_TASK
    name: Aprobar la release
    formId: release-approval
    preconditionStepId: notify-awaiting
    assignment:
      candidateGroups: [ publishers ]
      dueDate: P2D

  - id: decide
    type: CHOICE
    name: ¿Aprobada?
    preconditionStepId: approval

  - id: start-canary
    type: ACTION
    topic: publication-tasks
    name: Activar en canary
    compensable: true
    compensationStepId: abort-canary
    preconditions:
      - stepId: decide
        expression: "approved == 'true'"

  - id: notify-canary
    type: ACTION
    topic: publication-tasks
    name: Notificar «en canary»
    preconditionStepId: start-canary
    retries: 3

  - id: observe
    type: WAIT_FOR_MESSAGE
    name: Observar el canary (o recibir una decisión forzada)
    preconditionStepId: notify-canary
    messageName: canary-override
    correlationExpression: businessKey
    deadline:
      date: "${observeUntil}"
      zone: UTC
    onTimeoutStepId: evaluate

  - id: override
    type: ACTION
    topic: publication-tasks
    name: Aplicar la decisión forzada
    preconditionStepId: observe

  - id: evaluate
    type: ACTION
    topic: publication-tasks
    name: Evaluar las métricas del canary
    preconditions:
      - stepId: observe
        expression: "false"

  - id: verdict
    type: JOIN
    name: Veredicto
    joinType: XOR
    preconditionStepIds: [ override, evaluate ]

  - id: check
    type: CHOICE
    name: ¿Canary sano?
    preconditionStepId: verdict

  - id: promote
    type: ACTION
    topic: publication-tasks
    name: Promocionar a activa
    preconditions:
      - stepId: check
        expression: "healthy == 'true'"

  - id: notify-active
    type: ACTION
    topic: publication-tasks
    name: Notificar «activa»
    preconditionStepId: promote
    retries: 3

  - id: rollback
    type: ACTION
    topic: publication-tasks
    name: Deshacer el canary
    preconditions:
      - stepId: check

  - id: notify-rolled-back
    type: ACTION
    topic: publication-tasks
    name: Notificar «revertida»
    preconditionStepId: rollback
    retries: 3

  - id: notify-rejected
    type: ACTION
    topic: publication-tasks
    name: Notificar «rechazada»
    retries: 3
    preconditions:
      - stepId: decide

  - id: done
    type: JOIN
    name: Fin de la publicación
    joinType: XOR
    preconditionStepIds: [ notify-active, notify-rolled-back, notify-rejected ]

  - id: end
    type: END
    name: Fin
    preconditionStepId: done

  # Compensaciones (sin precondiciones: solo se ejecutan al compensar).
  - id: abort-canary
    type: ACTION
    topic: publication-tasks
    name: Anular el canary

  - id: notify-failed
    type: ACTION
    topic: publication-tasks
    name: Notificar «fallida»
    retries: 3
