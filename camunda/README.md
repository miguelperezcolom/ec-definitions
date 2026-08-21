# UC03 en Camunda 8

`uc03-overbooking.bpmn` es la traducción a Camunda 8 (Zeebe) de
[`definitions/workflows/uc03-overbooking-workflow.yml.ec`](../definitions/workflows/uc03-overbooking-workflow.yml.ec).
Está aquí y no en `definitions/` a propósito: el check de CI cuenta los ficheros de
`definitions/` y los compara con los que valida el plugin de EventConductor, y un `.bpmn`
ahí dentro pondría la cuenta en rojo.

## Todo por eventos

El requisito era que el proceso hable con los workers **sólo con eventos**, tanto para
arrancar el trabajo como para recibir el resultado. En BPMN eso son dos eventos por paso,
y en Camunda 8 los eventos no se pueden decorar con boundary events, así que cada paso
acaba siendo un subproceso embebido de cuatro elementos:

```
┌─ Registrar incidencia en CRM ─────────────────────────┐
│  (○) ──▶ (▶) run ──▶ (✉) done ──▶ (◉)                 │
└───────────────────────────────────────────────────────┘
       message throw     message catch
```

- **`run`** — message *throw* event. Es lo que arranca al worker.
- **`done`** — message *catch* event. El proceso se bloquea aquí hasta que el worker
  publica el evento de resultado.

Los nombres son mecánicos, uno por paso:

| dirección | nombre del mensaje |
|---|---|
| comando | `uc03.<pasoId>.run` |
| resultado | `uc03.<pasoId>.completed` |

Los 17 pasos (12 del flujo + 5 compensaciones) dan 34 mensajes declarados.

## El detalle que conviene saber

Zeebe **no publica el mensaje del throw event a un bus por su cuenta**: crea un job y exige
un `zeebe:taskDefinition`. Aquí todos usan el mismo tipo genérico, `publish-event`, con el
nombre del evento en las cabeceras:

```xml
<zeebe:taskDefinition type="publish-event" retries="1" />
<zeebe:taskHeaders>
  <zeebe:header key="eventName"       value="uc03.registerIncidence.run" />
  <zeebe:header key="resultEventName" value="uc03.registerIncidence.completed" />
  <zeebe:header key="step"            value="registerIncidence" />
</zeebe:taskHeaders>
```

Es decir, hace falta **un** worker `publish-event` que lea la cabecera, ponga el evento en
el bus y complete el job. Los workers de negocio no hablan con Zeebe para arrancar: se
suscriben al bus. Para devolver el resultado sí llaman a `PublishMessage` con el nombre
`uc03.<paso>.completed` y `correlationKey = reservationId`.

La correlación es siempre por `reservationId`, que es por tanto **variable obligatoria al
arrancar la instancia**.

## Cómo se mapea cada cosa

| EventConductor | Camunda 8 |
|---|---|
| `type: ACTION` | subproceso `run` → `done` |
| `type: USER_TASK` + `formId` | `bpmn:userTask` con `zeebe:userTask` y `zeebe:formDefinition formId="overbooking-form"` |
| `preconditions` con `expression` | gateway exclusivo con `conditionExpression` FEEL (`=decision = "REFUND"`) |
| `compensable` + `compensationStepId` | boundary event de compensación → handler con `isForCompensation="true"` |
| `timeout` | boundary timer event |
| `retries: 0` | `zeebe:taskDefinition retries="1"` (un intento, sin reintento) |

## Dos decisiones que no son traducción literal

1. **`onTimeoutStepId`.** En el `.ec`, el timeout de 90 s de la tarea humana salta a
   `cancelIncidence`, un paso concreto. Aquí el boundary timer dispara un
   *compensation throw event* sin `activityRef`, que compensa **todo** lo completado hasta
   ese momento en orden inverso, y termina en un terminate end event. Es lo idiomático en
   BPMN y lo que un saga espera; la diferencia es que también deshace
   `setReservationOverbookingStatus`, no sólo la incidencia.

2. **Los timeouts de 5 s** de `sendRefundNotification`, `confirmRefund`,
   `sendWalkNotification` y `confirmWalk` hacen lo mismo: rollback completo y terminate.
   En el `.ec` esos pasos simplemente fallan y el motor decide.

La rama `REJECT` no compensa, igual que en el `.ec`: ejecuta `rejectOverbooking` y termina.

## Desplegar

```bash
zbctl deploy resource camunda/uc03-overbooking.bpmn
```

El formulario `overbooking-form` tiene que estar desplegado aparte, como Camunda Form
(`.form`); el `.ecform` de este repo es el equivalente en EventConductor, no vale tal cual.

Validado contra el XSD de OMG:

```bash
xmllint --noout --schema BPMN20.xsd camunda/uc03-overbooking.bpmn
```
