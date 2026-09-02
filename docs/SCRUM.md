# Scrum adaptado al desarrollo de Sendaris

## Contexto

El desarrollo de Sendaris se realizará mediante una adaptación de Scrum
a un proyecto individual de titulación.

La adaptación conserva los elementos de planificación iterativa,
gestión del Product Backlog, desarrollo mediante Sprints, generación
de incrementos y revisión continua del trabajo.

No se simulan integrantes ni roles que no existen dentro del proyecto.

## Gestión del proyecto

GitHub será utilizado para el control de versiones del código fuente.

GitHub Projects será utilizado para la planificación, seguimiento
y trazabilidad de las actividades de desarrollo.

## Product Backlog

El Product Backlog estará compuesto por las Historias de Usuario
definidas previamente a partir de los Requerimientos Funcionales
y No Funcionales de Sendaris.

Cada Historia de Usuario mantendrá trazabilidad con:

- Requerimientos Funcionales.
- Requerimientos No Funcionales cuando corresponda.
- Sprint.
- Prioridad.
- Story Points.
- Epic.
- Código implementado.
- Commits.
- Pull Requests.

## Sprints

El desarrollo se organizará en seis Sprints de aproximadamente
dos semanas cada uno.

### Sprint 1
Base técnica, autenticación y persistencia.

### Sprint 2
Conductas y rutinas.

### Sprint 3
Sueño, alimentación, interacción social, desregulación emocional
y situaciones atípicas.

### Sprint 4
Historial, filtros e indicadores.

### Sprint 5
Reportes e integración funcional.

### Sprint 6
Línea temporal integrada, comparación de periodos
y cobertura de registros.

## Sprint Planning individual

Antes de iniciar cada Sprint se seleccionarán las Historias de Usuario
que puedan ser desarrolladas dentro de la iteración.

Las historias seleccionadas pasarán del estado:

Product Backlog → Ready

Cada historia tendrá asignados:

- Sprint.
- Prioridad.
- Story Points.
- Epic.
- RF relacionados.

## Seguimiento del trabajo

Durante cada Sprint se mantendrá actualizado el estado de las Historias
de Usuario mediante GitHub Projects.

El flujo utilizado será:

Product Backlog → Ready → In Progress → In Review → Done

Se procurará mantener una cantidad reducida de historias simultáneamente
en estado In Progress debido a que el proyecto es desarrollado por una
sola persona.

## Incremento

Al finalizar cada Sprint deberá existir un incremento funcional
del producto que pueda ser ejecutado y revisado.

Una funcionalidad incompleta no será considerada parte del incremento.

## Sprint Review individual

Al finalizar cada Sprint se verificará:

- Qué funcionalidades fueron implementadas.
- Qué criterios de aceptación fueron cumplidos.
- Qué Historias de Usuario fueron completadas.
- Qué incremento funcional fue obtenido.
- Qué elementos deberán continuar en el siguiente Sprint.

## Sprint Retrospective individual

Después de cada Sprint se registrará brevemente:

- Qué funcionó correctamente.
- Qué dificultades se presentaron.
- Qué aspectos pueden mejorarse.
- Qué acción se aplicará en el siguiente Sprint.

## Story Points

Los Story Points representan esfuerzo relativo, complejidad
e incertidumbre.

Se utilizará la siguiente escala:

- 1
- 2
- 3
- 5
- 8

Una historia que supere razonablemente los 8 Story Points deberá
ser revisada para determinar si puede dividirse.

## Definition of Done

Una Historia de Usuario será considerada Done cuando:

1. La funcionalidad esté implementada.
2. Cumpla sus criterios de aceptación.
3. Las validaciones correspondientes estén implementadas.
4. Respete las reglas de privacidad y seguridad del proyecto.
5. Utilice únicamente los datos previstos por el diseño.
6. No presente errores críticos conocidos.
7. Haya sido probada con datos ficticios.
8. Los commits estén relacionados con la Issue correspondiente.
9. Se haya creado y revisado el Pull Request.
10. El código haya sido integrado a la rama main.

## Gestión del código

La rama main representará el incremento estable de Sendaris.

El desarrollo de funcionalidades se realizará mediante ramas
temporales asociadas a las Historias de Usuario.

Ejemplo:

feature/HU-01-autenticacion

Los cambios serán integrados a main mediante Pull Requests.

## Evidencia de aplicación de Scrum

La evidencia del proceso estará compuesta por:

- Product Backlog en GitHub Projects.
- Sprint Board.
- Roadmap.
- Issues de Historias de Usuario.
- Story Points.
- Prioridades.
- Iterations.
- Commits.
- Pull Requests.
- Incrementos por Sprint.
- Sprint Reviews.
- Sprint Retrospectives.
