id: registrar-no-show
name: Registrar no-show
version: 1
description: >-
  Integración CRS ← hotel (PoC ACL, HLA F006): el hotel dice que los huéspedes de una reserva no han llegado; el CRS la cancela como no-show con su cargo. Lo que cuesta baja a Opera y al front office por la proyección de la cancelación.
steps:
  - id: start
    type: START
    name: Start
  # El CRS aplica su regla: cancela la reserva como no-show (motivo NOS) y la deja costando un
  # porcentaje de su precio original. Una vez: el mismo aviso dos veces es un solo no-show.
  - id: register-no-show
    type: ACTION
    name: Registrar el no-show en el CRS
    topic: booking
    timeout: PT2M
    retries: 10000
    preconditions:
      - stepId: start
  - id: end
    type: END
    name: Registrado
    preconditions:
      - stepId: register-no-show
