id: solicitud-empleado
name: Solicitud de un empleado
version: 1
description: >-
  Un empleado pide algo desde la intranet. Lo decide su responsable (a los dos días pasa al suyo) y
  después RRHH. Cada paso se publica en «solicitudes». Clave «solicitud:<id>».
steps:
  - id: start
    type: START
    name: Start

  - id: responsable
    type: USER_TASK
    name: La decide su responsable
    formId: aprobar-solicitud
    topic: forms
    preconditions:
      - stepId: start
    assignment:
      assignee: "${managerId}"
      priority: 60
      dueDate: P2D
    escalation:
      - after: P2D
        action: reassign
        to: { assignee: "${escalateToId ?: managerId}" }

  - id: decidido-responsable
    type: CHOICE
    name: ¿La aprueba su responsable?
    preconditions:
      - stepId: responsable

  - id: aprobada-responsable
    type: PUBLISH_EVENT
    name: Aprobada por su responsable, a RRHH
    preconditions:
      - stepId: decidido-responsable
        expression: decision == 'APROBAR'
    event:
      destination: solicitudes
      type: ec.solicitud.aprobada-responsable
      payload:
        requestId: "${requestId}"
        status: PENDIENTE_RRHH
        by: "${managerId}"
        comment: "${comentario ?: ''}"

  - id: rechazada-responsable
    type: PUBLISH_EVENT
    name: Rechazada por su responsable
    preconditions:
      - stepId: decidido-responsable
    event:
      destination: solicitudes
      type: ec.solicitud.rechazada
      payload:
        requestId: "${requestId}"
        status: RECHAZADA
        by: "${managerId}"
        comment: "${comentario ?: ''}"
  - id: fin-rechazada-responsable
    type: END
    name: Rechazada
    preconditions:
      - stepId: rechazada-responsable

  - id: rrhh
    type: USER_TASK
    name: La revisa RRHH
    formId: revisar-solicitud-rrhh
    topic: forms
    preconditions:
      - stepId: aprobada-responsable
    assignment:
      candidateUsers: ["${hrUserId}"]
      priority: 50
      dueDate: P3D

  - id: decidido-rrhh
    type: CHOICE
    name: ¿La aprueba RRHH?
    preconditions:
      - stepId: rrhh

  - id: aprobada
    type: PUBLISH_EVENT
    name: Aprobada
    preconditions:
      - stepId: decidido-rrhh
        expression: decisionRrhh == 'APROBAR'
    event:
      destination: solicitudes
      type: ec.solicitud.aprobada
      payload:
        requestId: "${requestId}"
        status: APROBADA
        by: "${hrUserId}"
        comment: "${comentarioRrhh ?: ''}"
  - id: fin-aprobada
    type: END
    name: Aprobada
    preconditions:
      - stepId: aprobada

  - id: rechazada-rrhh
    type: PUBLISH_EVENT
    name: Rechazada por RRHH
    preconditions:
      - stepId: decidido-rrhh
    event:
      destination: solicitudes
      type: ec.solicitud.rechazada
      payload:
        requestId: "${requestId}"
        status: RECHAZADA
        by: "${hrUserId}"
        comment: "${comentarioRrhh ?: ''}"
  - id: fin-rechazada-rrhh
    type: END
    name: Rechazada por RRHH
    preconditions:
      - stepId: rechazada-rrhh
