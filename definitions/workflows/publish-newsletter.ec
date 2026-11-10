# Publicación de la Newsletter PMO (frontend-public-refrenence, ADR-0059).
#
# Un mismo proceso para los dos motivos por los que hay que reconstruir el sitio estático:
#
#   - kind = issue    — sale un número: lo arranca el CMS o una persona con issueSlug y, si se
#                       programa, publishAt (fecha y hora en Europe/Madrid, u offset date-time).
#                       Pasa por la aprobación de un segundo usuario y, al activarse, se envía el
#                       aviso por email a los suscriptores (RF-11).
#   - kind = refresh  — refresco de los datos horneados (ServiceNow SPM, píldoras): lo arranca el
#                       cron diario (cron.yaml, newsletter-refresh). Sin aprobación y sin email.
#
#   esperar publishAt → construir sin activar → verificar → ¿refresco?
#     ├─ sí → activar
#     └─ no → aprobar → ¿aprobado? ── sí → activar → enviar el aviso
#                                  └─ no → descartar la construcción
#
# Sin publishAt el TIMER vence al momento (${publishAt ?: now}). Una fecha ya pasada también
# (ifPast: fire), así que un número programado no se pierde si el motor estaba parado a esa hora,
# a diferencia de un cron, que se salta las ocurrencias perdidas. Si el CMS cambia publishAt
# mientras el proceso espera, el TIMER se mueve con la variable.
#
# Los pasos ACTION los ejecuta el worker del publisher por el topic publication-tasks, el mismo de
# publish-release; sus ids llevan el prefijo nl- porque el worker resuelve el handler por el id del
# paso. Ningún kind desconocido se salta la aprobación: el camino por defecto es aprobar.
id: publish-newsletter
name: Publicar la Newsletter PMO
version: 1
# Un número rechazado se puede volver a enviar con la misma clave (newsletter-issue-<slug>); uno en
# curso, no: dos publicaciones del mismo número a la vez enviarían dos avisos.
businessKeyPolicy: allowAfterFinished
steps:
  - id: start
    type: START
    name: Inicio

  - id: wait-publish-at
    type: TIMER
    name: Esperar a la hora de publicación
    preconditionStepId: start
    until:
      date: "${publishAt ?: now}"
      zone: Europe/Madrid
      ifPast: fire

  - id: nl-build
    type: ACTION
    topic: publication-tasks
    name: Construir el sitio sin activarlo
    preconditionStepId: wait-publish-at
    timeout: PT20M

  - id: nl-verify
    type: ACTION
    topic: publication-tasks
    name: Verificar la construcción
    preconditionStepId: nl-build
    timeout: PT5M

  - id: route
    type: CHOICE
    name: ¿Refresco o número nuevo?
    preconditionStepId: nl-verify

  - id: nl-activate-refresh
    type: ACTION
    topic: publication-tasks
    name: Activar el refresco
    retries: 3
    preconditions:
      - stepId: route
        expression: "kind == 'refresh'"

  - id: approval
    type: USER_TASK
    name: Aprobar el número
    formId: newsletter-approval
    preconditions:
      - stepId: route
    assignment:
      candidateGroups: [ newsletter-publishers ]
      dueDate: P2D

  - id: decide
    type: CHOICE
    name: ¿Aprobado?
    preconditionStepId: approval

  - id: nl-activate
    type: ACTION
    topic: publication-tasks
    name: Activar el número
    retries: 3
    preconditions:
      - stepId: decide
        expression: "approved == 'true'"

  - id: nl-send-email
    type: ACTION
    topic: publication-tasks
    name: Enviar el aviso a los suscriptores
    preconditionStepId: nl-activate
    retries: 3

  - id: nl-discard
    type: ACTION
    topic: publication-tasks
    name: Descartar la construcción rechazada
    retries: 3
    preconditions:
      - stepId: decide

  - id: done
    type: JOIN
    name: Fin de la publicación
    joinType: XOR
    preconditionStepIds: [ nl-activate-refresh, nl-send-email, nl-discard ]

  - id: end
    type: END
    name: Fin
    preconditionStepId: done
