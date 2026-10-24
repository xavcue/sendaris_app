
# Scrum adaptado al desarrollo de Sendaris

## Contexto

El desarrollo de Sendaris se realiza mediante una adaptación de Scrum
a un proyecto individual de titulación en Ingeniería de Software.

La adaptación conserva los principios de planificación iterativa,
gestión del Product Backlog, desarrollo mediante Sprints,
generación de incrementos funcionales y revisión continua.

No se simulan integrantes, ceremonias grupales ni roles que no
existen dentro del proyecto.

Las actividades se documentan mediante Issues, GitHub Projects,
commits, Pull Requests y evidencias de pruebas.

## Gestión del proyecto

GitHub se utiliza para el control de versiones del código fuente.

GitHub Projects se utiliza para la planificación, seguimiento
y trazabilidad de las actividades de desarrollo.

La cuenta responsable del repositorio es `xavcue`.

El repositorio principal es `xavcue/sendaris_app`.

La rama `main` representa el incremento estable e integrado.

Las funcionalidades y mejoras se desarrollan mediante ramas
temporales, manteniendo aislados los cambios hasta su revisión.

## Alcance del producto

Sendaris es una aplicación móvil destinada al registro de
conductas y rutinas y al monitoreo descriptivo de indicadores
biopsicosociales en niños con TEA.

La implementación final está destinada exclusivamente a Android.

La distribución se realiza mediante un archivo APK para
los usuarios definidos por la institución.

No se contempla la publicación en tiendas de aplicaciones.

La aplicación mantiene las restricciones de anonimización,
minimización de datos, seguridad y ausencia de divulgación
de registros o reportes a terceros.

No se implementan diagnósticos, predicciones, tratamientos,
recomendaciones terapéuticas ni un índice biopsicosocial global.

## Product Backlog

El Product Backlog parte de las Historias de Usuario definidas
a partir de los 24 Requerimientos Funcionales y los
14 Requerimientos No Funcionales del proyecto.

También puede incorporar ampliaciones técnicas, correcciones,
mejoras de interfaz y tareas de documentación surgidas
durante la implementación.

Estas ampliaciones no se convierten automáticamente en
nuevas Historias de Usuario académicas.

Cada elemento debe mantener, cuando corresponda,
trazabilidad con:

- Identificador de Issue.
- Historia de Usuario o ampliación técnica relacionada.
- Requerimientos Funcionales.
- Requerimientos No Funcionales.
- Épica.
- Sprint o iteración asignada.
- Prioridad.
- Story Points.
- Criterios de aceptación.
- Código implementado.
- Pruebas y evidencias.
- Commits.
- Pull Request.
- Estado de integración.

Los cambios de alcance deben quedar documentados sin
alterar retrospectivamente las evidencias históricas.

## Épicas del producto

La organización funcional conserva las siguientes épicas:

- EP-01: Acceso, privacidad y base técnica.
- EP-02: Registro de conductas y rutinas.
- EP-03: Registro de dimensiones cotidianas.
- EP-04: Historial y métricas descriptivas.
- EP-05: Visualización y reportes.
- EP-06: Seguimiento contextual integrado.

Las ampliaciones de autenticación, seguridad y sesiones
se relacionan principalmente con EP-01.

## Sprints

La planificación académica original contempla seis Sprints
de aproximadamente dos semanas cada uno.

Las actividades pueden ajustarse según las dependencias,
el esfuerzo real y las necesidades de implementación.

### Sprint 1

Base técnica, autenticación, anonimización,
persistencia y recuperación segura.

### Sprint 2

Registro de conductas, administración de rutinas,
estados de rutinas y situaciones atípicas.

### Sprint 3

Registro de sueño, alimentación, interacción social
y desregulación emocional.

### Sprint 4

Historial, filtros, frecuencias descriptivas,
duraciones, promedios y cumplimiento de rutinas.

### Sprint 5

Visualización, reportes internos e integración funcional.

### Sprint 6

Línea temporal integrada, comparación descriptiva
entre periodos y cobertura de registros.

## Refinamiento y ampliaciones posteriores

La planificación original de seis Sprints se conserva
como referencia académica del Product Backlog.

Durante el desarrollo pueden identificarse necesidades
adicionales de seguridad, autenticación, usabilidad,
compatibilidad o mantenimiento.

Estas actividades se registran mediante Issues específicas,
con criterios de aceptación verificables y trazabilidad
a los requerimientos correspondientes.

Las ampliaciones técnicas no requieren crear una nueva
Historia de Usuario académica cuando complementan
historias existentes.

Ejemplos de ampliaciones técnicas:

- AUTH-01: Recuperación segura de contraseña.
- AUTH-02: Autenticación mediante Google.
- AUTH-03: Vinculación biométrica y gestión segura
  de sesiones independientes.
- Mejoras de Inicio, navegación, indicadores y ajustes.
- Ajustes de compatibilidad y seguridad de Android.

Estas actividades deben conservar sus identificadores
originales en Issues, commits y Pull Requests.

Los cambios técnicos posteriores no implican modificar
los objetivos específicos del proyecto ni crear
automáticamente nuevos Sprints académicos.

## Sprint Planning individual

Antes de iniciar una iteración se seleccionan los
elementos del Product Backlog que pueden desarrollarse
según su prioridad, dependencias y esfuerzo.

El estado inicial de planificación es:

Product Backlog → Ready

Cada elemento deberá tener, cuando corresponda:

- Identificador y descripción.
- Épica relacionada.
- Sprint o iteración.
- Prioridad.
- Story Points.
- Requerimientos relacionados.
- Criterios de aceptación.
- Dependencias conocidas.

No se asignarán valores de planificación ficticios
para completar campos sin una decisión documentada.

## Story Points

Los Story Points representan esfuerzo relativo,
complejidad, incertidumbre y trabajo de integración.

Se utiliza la siguiente escala:

- 1
- 2
- 3
- 5
- 8

Una actividad cuyo esfuerzo supere razonablemente
los 8 Story Points deberá revisarse para determinar
si puede dividirse en entregables verificables.

Los Story Points no equivalen directamente a horas.

## Seguimiento del trabajo

El flujo de trabajo de GitHub Projects es:

Product Backlog → Ready → In Progress → In Review → Done

### Product Backlog

Actividad identificada y pendiente de planificación.

### Ready

Actividad definida con alcance y criterios de aceptación
suficientes para iniciar su implementación.

### In Progress

Actividad en desarrollo, corrección o validación.

### In Review

Implementación preparada para revisión mediante
Pull Request, con las pruebas y evidencias necesarias.

### Done

Actividad que cumple los criterios de aceptación
y la Definition of Done.

La aprobación de pruebas locales no equivale por sí sola
a completar una actividad.

## Historias de Usuario e Issues

Las Historias de Usuario utilizan la plantilla:

`.github/ISSUE_TEMPLATE/historia_usuario.md`

La plantilla contiene:

- Historia de Usuario.
- Requerimientos relacionados.
- Criterios de aceptación.
- Consideraciones técnicas.
- Pruebas.
- Definition of Done.

Las ampliaciones técnicas pueden utilizar una Issue
específica, conservando esas mismas exigencias
de trazabilidad y verificabilidad.

Los criterios de aceptación solo se marcan como cumplidos
cuando existe evidencia suficiente.

Una Issue no se cierra únicamente porque las pruebas
automatizadas hayan terminado correctamente.

## Gestión del código

La rama `main` representa el incremento estable.

El desarrollo se realiza mediante ramas temporales
relacionadas con las actividades correspondientes.

Ejemplos:

- `feat/biometria-persistente-android`
- `feat/google-sign-in-android`

Los cambios se integran a `main` mediante Pull Requests.

No se realiza una integración directa sin la revisión
de los cambios y de sus evidencias.

No se deben utilizar comandos destructivos para limpiar
archivos locales sin identificar previamente su finalidad.

## Commits

Los commits deben identificar claramente la funcionalidad
o actividad relacionada.

Se utilizarán mensajes descriptivos, por ejemplo:

`feat(auth): incorporar autenticacion biometrica (AUTH-03)`

`test(auth): ampliar pruebas de sesiones A/B (AUTH-03)`

`docs: actualizar trazabilidad y seguridad (AUTH-03)`

Una Issue puede relacionarse con varios commits
cuando la implementación lo requiera.

Los archivos incluidos deben corresponder al alcance
de la actividad documentada.

Antes de publicar cambios deberán verificarse
los archivos preparados, sus diferencias y la
ausencia de información sensible.

## Pull Requests

Los Pull Requests utilizan la plantilla:

`.github/pull_request_template.md`

Cada Pull Request debe documentar:

- Historia de Usuario o ampliación técnica relacionada.
- Requerimientos Funcionales.
- Requerimientos No Funcionales.
- Cambios realizados.
- Criterios de aceptación verificados.
- Pruebas realizadas.
- Verificación de privacidad y seguridad.
- Issue relacionada.

El Pull Request debe disponer de un título descriptivo,
descripción completa, etiquetas y responsable.

El responsable habitual del repositorio es `xavcue`.

Cuando corresponda, se actualizará su información
en GitHub Projects.

No se indicará que una prueba fue aprobada si
no existe una ejecución o evidencia correspondiente.

La revisión debe comprobar que el Pull Request
solo incorpora los archivos previstos.

La referencia `Closes #N` se utiliza cuando el Pull
Request completa la Issue correspondiente.

Si la integración es parcial, se utilizará una referencia
sin cierre automático.

## Validación técnica

Las validaciones se seleccionan según el alcance
de cada funcionalidad.

Pueden incluir:

- Formato de código Dart.
- Análisis estático de Flutter.
- Pruebas unitarias.
- Pruebas de widgets.
- Pruebas de integración.
- Regresión de autenticación y sesiones.
- Pruebas de aislamiento entre cuentas.
- Pruebas de persistencia y recuperación.
- Pruebas de reglas de seguridad de Firestore.
- Comprobaciones manuales en emulador o dispositivo.
- Comprobación de integridad de Git.

Las pruebas deben realizarse utilizando datos ficticios.

En cambios relacionados con autenticación o sesiones,
debe verificarse que no exista acceso no autorizado
ni exposición de datos durante las transiciones.

Los resultados deben documentarse en la Issue
o en el Pull Request correspondiente.

## Privacidad y seguridad

Los incrementos deben cumplir:

`docs/SECURITY_GUARDRAILS.md`

Antes de la integración se verificará que:

- No se incorporen identificadores directos del niño.
- No se publiquen secretos o credenciales.
- Los datos de seguimiento mantengan su anonimización.
- La información permanezca aislada por usuario.
- Las funciones protegidas exijan autorización válida.
- No se incorporen funciones de divulgación a terceros.
- Las comunicaciones técnicas tengan finalidad legítima.
- Las operaciones destructivas mantengan sus verificaciones.
- Los cambios respeten las restricciones del proyecto.

Las revisiones de seguridad se realizarán sobre
el código y los archivos efectivamente modificados.

## Incremento

Al finalizar una iteración deberá existir un
incremento funcional ejecutable y verificable.

Una funcionalidad incompleta no será considerada
parte del incremento estable.

La implementación local puede considerarse validada
sin que su Issue alcance todavía el estado Done.

Su integración definitiva requiere completar
la revisión del Pull Request.

## Sprint Review individual

Durante la revisión se verificará:

- Qué funcionalidades fueron implementadas.
- Qué criterios de aceptación se cumplieron.
- Qué pruebas fueron ejecutadas.
- Qué evidencias se encuentran disponibles.
- Qué incremento funcional fue obtenido.
- Qué actividades quedaron pendientes.
- Qué cambios se integraron a `main`.

## Sprint Retrospective individual

Después de cada iteración se registrará:

- Qué funcionó correctamente.
- Qué dificultades se presentaron.
- Qué aspectos pueden mejorarse.
- Qué acciones correctivas se aplicaron.
- Qué mejoras se considerarán en el trabajo posterior.

## Definition of Done

Una Historia de Usuario o ampliación técnica
será considerada Done cuando:

1. La funcionalidad esté implementada.
2. Se cumplan sus criterios de aceptación.
3. Las validaciones correspondientes estén implementadas.
4. Se respeten las reglas de privacidad y seguridad.
5. Se utilicen únicamente los datos previstos por el diseño.
6. No existan errores críticos conocidos.
7. Se hayan realizado las pruebas aplicables con datos ficticios.
8. Los commits estén relacionados con la Issue.
9. El Pull Request haya sido creado y revisado.
10. El código esté integrado a `main`.
11. La trazabilidad y las evidencias estén documentadas.
12. La Issue y el estado de GitHub Projects reflejen
    correctamente la finalización.

Los puntos anteriores no sustituyen los criterios
de aceptación particulares de cada actividad.

## Cierre de actividades

Antes de cerrar una Issue se comprobará:

- Que los criterios de aceptación estén verificados.
- Que las pruebas relevantes hayan sido aprobadas.
- Que no existan problemas críticos pendientes.
- Que el Pull Request esté fusionado.
- Que la rama principal contenga el incremento.
- Que la documentación necesaria esté actualizada.
- Que el estado de GitHub Projects sea coherente.

Las ramas temporales podrán eliminarse después
de comprobar la integración, siempre que no existan
trabajos pendientes asociados.

## Evidencia de aplicación de Scrum

La evidencia del proceso estará compuesta por:

- Product Backlog en GitHub Projects.
- Sprint Board.
- Roadmap.
- Issues de Historias de Usuario.
- Issues de ampliaciones técnicas.
- Story Points.
- Prioridades.
- Iteraciones.
- Commits.
- Pull Requests.
- Resultados de pruebas.
- Incrementos funcionales.
- Sprint Reviews.
- Sprint Retrospectives.
- Evidencia de integración en `main`.
