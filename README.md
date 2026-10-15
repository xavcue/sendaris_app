# Sendaris

Sendaris es una aplicación móvil para Android desarrollada como proyecto de titulación, destinada al registro de conductas y rutinas, así como al procesamiento y monitoreo descriptivo de indicadores biopsicosociales en niños con trastorno del espectro autista (TEA).

El repositorio contiene el código fuente, las configuraciones técnicas, las pruebas y los recursos necesarios para el desarrollo y mantenimiento de la aplicación.

## Objetivo

Desarrollar una aplicación móvil que permita registrar conductas y rutinas, procesar la información registrada y monitorear indicadores biopsicosociales descriptivos mediante historiales, tendencias, gráficos y reportes, proporcionando una herramienta organizada, comprensible y segura.

## Plataforma

Sendaris está desarrollada con Flutter y Dart exclusivamente para dispositivos móviles Android.

La aplicación se distribuye mediante un archivo APK que puede instalarse directamente en dispositivos Android compatibles.

No se contempla el desarrollo de versiones para iOS, web o escritorio, ni la publicación de la aplicación en Google Play Store u otras tiendas virtuales.

## Alcance funcional

La aplicación contempla las siguientes funcionalidades:

- Autenticación y gestión de cuentas de usuario.
- Administración de seguimientos asociados a identificadores internos anónimos.
- Registro de conductas.
- Registro de sueño.
- Registro general de alimentación.
- Registro de interacción social.
- Registro de episodios de desregulación emocional.
- Registro de otras situaciones.
- Creación, edición y administración de rutinas.
- Registro y consulta de estados de rutinas.
- Consulta de historiales de registros.
- Organización cronológica de la información.
- Procesamiento de indicadores descriptivos.
- Visualización de tendencias y gráficos.
- Comparación descriptiva entre periodos.
- Consulta de cobertura de registros.
- Generación y consulta interna de reportes.

Las funcionalidades se implementan y validan progresivamente de acuerdo con los requerimientos y las historias de usuario del proyecto.

## Privacidad y seguridad

Sendaris utiliza identificadores internos anónimos para organizar los seguimientos.

Los registros no deben contener nombres, apellidos, números de identificación, fotografías, direcciones, instituciones educativas, historias clínicas ni otros datos que permitan identificar directamente a los niños.

Los datos de autenticación de los usuarios autorizados se mantienen separados lógicamente de los registros de seguimiento.

La aplicación incorpora mecanismos de protección mediante:

- Firebase Authentication para autenticación y gestión de cuentas.
- Cloud Firestore para persistencia remota.
- Firestore Security Rules para autorización y control de acceso.
- Firebase App Check para contribuir a proteger los servicios de Firebase.
- Validaciones funcionales y controles de acceso asociados a cada usuario.

La aplicación no incorpora funcionalidades destinadas a publicar, enviar o compartir registros y reportes de seguimiento con terceros.

## Firebase App Check

Durante el desarrollo y las pruebas en modo Debug se utiliza Android Debug Provider.

Para las compilaciones Release se utiliza Android Play Integrity Provider.

Las compilaciones destinadas a instalación directa mediante APK requieren una configuración de integridad compatible con la distribución fuera de Google Play Store.

Los tokens Debug de Firebase App Check no deben incluirse en el código fuente, compartirse públicamente ni incorporarse a los APK de distribución.

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

Sendaris utiliza una arquitectura modular organizada por funcionalidades, aplicando separación de responsabilidades mediante:

- MVVM (Model-View-ViewModel).
- Repositories.
- Services.

La organización del proyecto separa las capas de presentación, dominio y acceso a datos para facilitar su mantenimiento, evolución y comprobación funcional.

## Persistencia y sincronización

Cloud Firestore constituye la fuente remota de almacenamiento de los registros.

La aplicación utiliza las capacidades de persistencia local y sincronización proporcionadas por Firestore.

La recuperación y sincronización de información deben respetar los mecanismos de autenticación, autorización y aislamiento entre cuentas.

## Restricciones del proyecto

Sendaris:

- No realiza diagnósticos médicos, psicológicos ni nutricionales.
- No prescribe tratamientos.
- No predice conductas.
- No emite recomendaciones clínicas automáticas.
- No utiliza inteligencia artificial ni aprendizaje automático para interpretar los registros.
- No genera conclusiones clínicas a partir de indicadores descriptivos.
- No calcula un índice biopsicosocial global.
- No publica ni comparte los registros de seguimiento con terceros.

Los indicadores generados son exclusivamente descriptivos y se basan en la información registrada dentro de la aplicación.

## Metodología de desarrollo

El proyecto utiliza Design Science Research Methodology (DSRM) como metodología general y una adaptación de Scrum para organizar el desarrollo de software.

El trabajo se estructura mediante:

- Product Backlog.
- Historias de usuario.
- Sprint Planning.
- Sprint Backlog.
- Sprints.
- Incrementos funcionales.
- Sprint Review.
- Sprint Retrospective.
- Definition of Done.

GitHub Issues, Pull Requests y GitHub Projects se utilizan para la planificación, trazabilidad y control de cambios.

## Requisitos de desarrollo

Para trabajar con el proyecto se requiere:

- Flutter SDK compatible con la versión indicada en el proyecto.
- Dart SDK.
- Android SDK.
- Java y Gradle compatibles con la configuración Android.
- Un dispositivo Android o emulador configurado.
- Acceso autorizado al proyecto Firebase correspondiente.

## Ejecución del proyecto

Instalar las dependencias:

```bash
flutter pub get
```

Verificar el entorno:

```bash
flutter doctor
```

Consultar los dispositivos disponibles:

```bash
flutter devices
```

Ejecutar la aplicación en un emulador Android:

```bash
flutter run -d emulator-5554
```

El identificador del dispositivo puede variar según el entorno.

## Validación

Ejecutar el análisis estático:

```bash
flutter analyze
```

Ejecutar las pruebas Flutter:

```bash
flutter test
```

Compilar un APK Android de depuración:

```bash
flutter build apk --debug
```

Esta compilación se utiliza para desarrollo y pruebas. No debe confundirse con un APK Release preparado para distribución.

Las modificaciones a las reglas de seguridad de Firestore deben validarse previamente mediante pruebas con el emulador de Firebase.

## Compilación Android

El producto de distribución se genera mediante una compilación Android Release.

Antes de preparar un APK de distribución deben verificarse:

- Firma Release con un certificado propio.
- Configuración de Firebase App Check compatible con instalación directa.
- Funcionamiento de Firebase Authentication.
- Acceso autorizado a Cloud Firestore.
- Persistencia y sincronización.
- Instalación en dispositivos Android compatibles.
- Cumplimiento de los requerimientos funcionales y de seguridad.

## Pruebas y evaluación

Durante el desarrollo y la evaluación académica se utilizan datos ficticios.

Las pruebas contemplan validaciones funcionales, de integración, compatibilidad, rendimiento, seguridad, control de acceso y manejo de datos.

Los resultados permiten comprobar el cumplimiento de los requerimientos funcionales y no funcionales definidos para la aplicación.

## Proyecto de titulación

**Título académico:**

*Desarrollo de una aplicación móvil para el registro de conductas y rutinas, así como para el monitoreo de indicadores biopsicosociales en niños con trastorno del espectro autista.*