# Activación forzada de una release revertida por el criterio del canary (ADR-0051).
#
# Lo arranca el control-plane (ForceReleaseUseCase) con releaseId y forcedBy, tras comprobar que quien
# fuerza no es autor de la release y que no hay otra publicación en curso.
id: force-activate-release
name: Forzar la activación de una release
version: 1
steps:
  - id: start
    type: START
    name: Inicio

  - id: check-release
    type: ACTION
    topic: publication-tasks
    name: Comprobar que la release sigue en el CDN
    preconditionStepId: start
    compensable: true
    compensationStepId: notify-failed

  - id: force-activate
    type: ACTION
    topic: publication-tasks
    name: Activar la release
    preconditionStepId: check-release

  - id: notify-forced-active
    type: ACTION
    topic: publication-tasks
    name: Notificar «activa»
    preconditionStepId: force-activate
    retries: 3

  - id: end
    type: END
    name: Fin
    preconditionStepId: notify-forced-active

  # Compensación (sin precondiciones: solo se ejecuta al compensar).
  - id: notify-failed
    type: ACTION
    topic: publication-tasks
    name: Notificar «fallida»
    retries: 3
