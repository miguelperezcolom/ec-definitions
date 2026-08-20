# ec-definitions

Definiciones de workflows y formularios de [EventConductor](https://github.com/miguelperezcolom/eventconductor).

Aquí no hay código. Hay datos: ficheros planos que describen procesos y formularios, y que el
motor importa. Lo único que aporta este repositorio, además de guardarlos, es **comprobar que
son correctos antes de que lleguen a `master`** — porque una definición inválida no falla al
escribirla, falla cuando el motor la carga, y para entonces ya está desplegada.

## Estructura

```
definitions/
  workflows/*.ec        procesos
  forms/*.ecform        formularios (los referencian los pasos USER_TASK por su id)
```

Los ficheros son **YAML**. Las extensiones `.ec` y `.ecform` son las que registran el editor
de grafos y los plugins de IntelliJ y VS Code, que abren estos ficheros en un editor partido
—texto a un lado, grafo interactivo al otro— y les asocian el JSON Schema para autocompletar.
Renombrarlos a `.yaml` funcionaría igual para el motor, pero perderías eso.

`definitions/rules/*.ecrule` sería el tercer tipo. Todavía no hay ninguna: mira las
[limitaciones](#limitaciones-conocidas) antes de añadirlas.

## Validar en local

```bash
mvn verify
```

```
EventConductor: 6 definition(s) validated successfully.
```

El `pom.xml` sólo existe para esto: no compila nada, no produce artefacto. Ejecuta el
[`workflow-maven-plugin`](https://github.com/miguelperezcolom/eventconductor/blob/main/doc/src/content/docs/reference/maven-plugin.md),
que valida cada fichero contra el mismo JSON Schema que embarca el motor
([workflows](https://github.com/miguelperezcolom/eventconductor/blob/main/modules/workflow-engine/src/main/resources/workflow-definition-schema.json),
[formularios](https://github.com/miguelperezcolom/eventconductor/blob/main/modules/forms-engine/src/main/resources/form-schema.json))
y añade lo que un esquema no puede expresar: ids duplicados, precondiciones que apuntan a
pasos inexistentes, ciclos, expresiones JEXL que no parsean, crons inválidos, y la regla de
que todo paso sin precondición sea un `START` o un `WAIT_FOR_MESSAGE`.

Un error se ve así, citando el fichero:

```
definitions/workflows/order-fulfilment.ec:
  - Step 'ship-order' references unknown precondition step 'reviw-shipping'.
  - Step 'cancel-order' references unknown precondition step 'reviw-shipping'.
```

`mvn eventconductor:validate` hace lo mismo sin pasar por el ciclo de vida.

## Cómo se llega a `master`

`master` está protegida. No admite push directo —tampoco de administradores— y para mergear
hace falta un PR con el check `Validate workflows & forms` en verde, y la rama al día con
`master`.

```bash
git checkout -b mi-cambio
# editar definitions/...
mvn verify                    # falla aquí antes que en CI
git commit -am "..." && git push -u origin mi-cambio
gh pr create
```

La Action (`.github/workflows/validate.yml`) corre `mvn verify` y después un segundo paso que
compara cuántas definiciones hay en `definitions/` con cuántas dice el plugin haber validado.
Parece redundante y no lo es: el modo en que esto se rompe es **en verde**. Un validador que
no reconoce una extensión no protesta, informa de cero ficheros y da el build por bueno. Pasó
exactamente eso, y ese paso es lo que impide que vuelva a pasar en silencio.

## Añadir una definición

1. Crea el fichero en `definitions/workflows/` o `definitions/forms/`.
2. Dale un `id` explícito. Sin él, el motor lo deriva de la ruta del fichero, y mover el
   fichero cambiaría entonces a qué apuntan los pasos que lo referencian.
3. `mvn verify`.
4. PR.

La referencia de cada campo está en las guías de
[workflows](https://github.com/miguelperezcolom/eventconductor/blob/main/doc/src/content/docs/guides/workflow-definitions.md)
y [formularios](https://github.com/miguelperezcolom/eventconductor/blob/main/doc/src/content/docs/guides/form-definitions.md).
`definitions/workflows/order-fulfilment.ec` es el ejemplo largo: usa fork/join, tarea humana,
timeouts, reintentos y compensación saga, y está comentado paso a paso.

## Cómo llegan al motor

Con `workflow.persistence=jpa`, EventConductor clona repositorios de definiciones y las
importa: al arrancar, bajo demanda por MCP, o automáticamente por webhook de git. Se
configura del lado del motor, no de aquí:

```yaml
workflow:
  git-import:
    repositories:
      - url: https://github.com/miguelperezcolom/ec-definitions.git
        branch: master
```

Un `id` que ya existe se sobrescribe. Los detalles, incluido el webhook, en la
[guía de workflows](https://github.com/miguelperezcolom/eventconductor/blob/main/doc/src/content/docs/guides/workflow-definitions.md#importing-from-git).

## Limitaciones conocidas

- **Las reglas no están validadas.** `validateRules` está a `false` en el `pom.xml` porque no
  hay `definitions/rules/`. Al crear ese directorio hay que ponerlo a `true`; si se olvida, el
  paso de CI que cuenta definiciones lo detecta.
- **El motor no importa `.ecrule` desde git.** `ImportRulesFromGitUseCase` filtra sólo
  `.json` / `.yaml` / `.yml`, al contrario que los de workflows y formularios, que sí aceptan
  `.ec` y `.ecform`. Hasta que eso se arregle upstream, una regla en este repositorio tiene
  que llamarse `.yaml` para que el motor la vea — aunque el validador ya la acepte con
  cualquiera de las dos.
- Requiere **JDK 21** y el plugin **2.3.0 o superior**. Bajar de 2.3.0 no da error: esa es la
  primera versión que lee `.ec`, y las anteriores simplemente no encuentran nada y pasan en
  verde.
