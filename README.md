# Sendaris

Sendaris es una aplicación móvil desarrollada como proyecto de titulación para el registro de conductas y rutinas, así como para el monitoreo descriptivo de indicadores biopsicosociales en niños con trastorno del espectro autista (TEA).

El repositorio contiene el código fuente, la configuración técnica y los recursos necesarios para el desarrollo de la aplicación móvil.

## Objetivo

Implementar una aplicación móvil que permita registrar conductas y rutinas, así como generar y monitorear indicadores biopsicosociales, para facilitar el seguimiento mediante una herramienta organizada, comprensible y segura.

## Plataformas

Sendaris está planteada como una aplicación móvil multiplataforma desarrollada con Flutter para:

- Android
- iOS

La aplicación comparte una misma base de código y utiliza servicios administrados de Firebase para autenticación, persistencia y controles de seguridad.

## Alcance

Sendaris permitirá:

- Registrar conductas.
- Registrar horas de sueño.
- Registrar información general de alimentación.
- Registrar interacción social.
- Registrar episodios de desregulación emocional.
- Registrar situaciones atípicas.
- Crear y administrar rutinas.
- Registrar el estado de las rutinas.
- Consultar historial de registros.
- Visualizar indicadores descriptivos.
- Visualizar tendencias.
- Comparar periodos.
- Consultar cobertura de registros.
- Generar reportes internos.

## Privacidad y seguridad

Los registros relacionados con los niños no utilizarán identificadores personales directos. El seguimiento se asociará a identificadores internos anónimos definidos por el sistema.

Los datos de autenticación de los usuarios autorizados se mantienen separados lógicamente de los datos de seguimiento.

La aplicación incorpora controles de acceso y seguridad mediante Firebase Authentication, Cloud Firestore Security Rules y Firebase App Check.

Sendaris no incluirá funciones destinadas a publicar, compartir, enviar o divulgar los registros de seguimiento a terceros.

## Tecnologías principales

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firestore Security Rules
- Firebase App Check
- Provider
- go_router
- UUID
- Git
- GitHub

## Arquitectura

La aplicación utiliza una arquitectura organizada por funcionalidades y separación de responsabilidades mediante:

- MVVM
- Repositories
- Services

La estructura del proyecto separa las capas de presentación, dominio y acceso a datos para facilitar el mantenimiento, las pruebas y la evolución de la aplicación.

## Persistencia

Cloud Firestore se utiliza como fuente remota de datos.

La aplicación contempla persistencia local y sincronización mediante las capacidades offline de Firestore, manteniendo el acceso remoto restringido al ámbito autorizado de cada usuario.

## Restricciones del proyecto

Sendaris:

- No realiza diagnósticos.
- No prescribe tratamientos.
- No predice conductas.
- No emite recomendaciones clínicas.
- No utiliza inteligencia artificial.
- No calcula un índice de calidad de vida.
- No publica ni comparte información de seguimiento con terceros.

Los indicadores generados son exclusivamente descriptivos y se basan en la información registrada en la aplicación.

## Metodología de desarrollo

El desarrollo de Sendaris se realiza mediante una adaptación de Scrum para un proyecto individual.

Se utilizan:

- Product Backlog
- Historias de Usuario
- Sprint Planning
- Sprint Backlog
- Sprints
- Incrementos
- Sprint Review
- Sprint Retrospective
- Definition of Done

GitHub Issues y GitHub Projects se utilizan para la planificación y trazabilidad del desarrollo.

## Ejecución del proyecto

Instalar las dependencias:

```bash
flutter pub get
```

Verificar el entorno:

```bash
flutter doctor
```

Ejecutar la aplicación en un dispositivo o emulador disponible:

```bash
flutter run
```

## Proyecto de titulación

**Título académico:**  
*Desarrollo de una aplicación móvil para el registro de conductas y rutinas, así como para el monitoreo de indicadores biopsicosociales en niños con trastorno del espectro autista.*
