
# Salvaguardas de privacidad y seguridad de Sendaris

## Finalidad

Este documento establece las restricciones técnicas
transversales destinadas a proteger la información
de seguimiento utilizada por Sendaris.

Las salvaguardas se fundamentan en los principios
de minimización, anonimización, autenticación,
autorización, integridad y privacidad desde el diseño.

Estas condiciones deben mantenerse durante el
desarrollo, las pruebas, la integración y la distribución.

## Alcance

Sendaris es una aplicación móvil para Android destinada
al registro de conductas, rutinas y dimensiones cotidianas,
así como al monitoreo de indicadores descriptivos.

La aplicación se distribuye mediante APK para
los usuarios definidos por la institución.

No se contempla publicación en tiendas de aplicaciones.

No se utiliza infraestructura institucional propia
para almacenar los registros.

Los servicios remotos forman parte de la arquitectura
técnica y no constituyen mecanismos de divulgación.

## Anonimización de los seguimientos

Los registros de seguimiento se asocian exclusivamente
a identificadores internos anónimos.

No deben almacenarse datos que permitan identificar
directamente a los niños, incluyendo:

- Nombres y apellidos.
- Números de identificación.
- Fotografías.
- Direcciones.
- Instituciones educativas.
- Historias clínicas.
- Fechas de nacimiento.
- Otros identificadores personales directos.

No debe implementarse una tabla interna que relacione
el identificador anónimo con la identidad real del niño.

Los campos descriptivos de texto libre no deben utilizarse
para introducir información personal identificable.

Los datos de autenticación del usuario autorizado
deben mantenerse separados lógicamente de los
registros del niño.

## Prohibición de divulgación funcional

Sendaris no debe incorporar funcionalidades destinadas a:

- Compartir registros de seguimiento.
- Enviar registros o reportes a terceros.
- Publicar registros o reportes.
- Enviar información de seguimiento por correo electrónico.
- Enviar información de seguimiento mediante SMS.
- Compartir información mediante mensajería.
- Integrar redes sociales para divulgar registros.
- Ofrecer botones de compartición de reportes.
- Exportar información con finalidad de divulgación externa.

Estas restricciones corresponden principalmente
a HU-18, RF-20 y RNF-12.

La generación y consulta interna de reportes no autoriza
su divulgación a otros usuarios o destinatarios externos.

## Comunicaciones técnicas permitidas

Las comunicaciones externas se limitan a las necesarias
para el funcionamiento legítimo y seguro del sistema.

Entre ellas se encuentran:

- Firebase Authentication.
- Cloud Firestore.
- Firebase App Check.
- Persistencia remota de registros.
- Recuperación segura de información.
- Sincronización técnica de datos.
- Verificación de direcciones de correo electrónico.
- Recuperación de contraseñas.
- Autenticación mediante proveedores habilitados.

Los correos de verificación y recuperación gestionados
por el proveedor de autenticación son comunicaciones
técnicas y no mecanismos de divulgación de registros.

No deben incluir datos de seguimiento del niño.

Las comunicaciones deben respetar la finalidad
del sistema y los controles de seguridad aplicables.

## Autenticación y autorización

El acceso a las funcionalidades protegidas requiere
una identidad Firebase válida y autorizada.

La autenticación puede utilizar los mecanismos
habilitados por la implementación, incluyendo:

- Correo electrónico y contraseña.
- Inicio de sesión mediante Google.
- Autorización biométrica local para una cuenta vinculada.

La biometría local no sustituye la autenticación
ni la autorización exigida por Firebase.

La verificación de correo electrónico y las
restricciones de cuenta deben mantenerse conforme
a la política de autenticación implementada.

No se concede acceso a datos de seguimiento
por la sola existencia de un identificador local.

## Arquitectura de cuentas A/B

La implementación de AUTH-03 contempla dos contextos
de acceso diferenciados.

### Cuenta A

Representa la cuenta vinculada biométricamente
a la instalación.

La vinculación se asocia a un UID específico.

La autorización biométrica debe utilizar los
mecanismos nativos de seguridad compatibles
con el dispositivo Android.

La existencia del vínculo no concede por sí sola
acceso a los datos privados.

### Cuenta B

Representa una cuenta con autenticación convencional.

Su acceso se realiza mediante los proveedores
de autenticación habilitados por la aplicación.

La cuenta B no utiliza la autorización biométrica
de la cuenta A.

### Aislamiento entre cuentas

Las cuentas A y B deben mantener separados:

- Sus identificadores de usuario.
- Sus contextos de autenticación.
- Sus autorizaciones de acceso.
- Sus registros de sesión.
- Sus seguimientos.
- Sus datos privados.
- Sus operaciones de cierre y revocación.

El cambio A → B → A no autoriza reutilizar
las credenciales ni los permisos de otra cuenta.

El ingreso convencional de B no debe eliminar
automáticamente la vinculación biométrica de A.

No se permite seleccionar identidades únicamente
por coincidencia de direcciones de correo electrónico.

## Protección biométrica

La integración biométrica utiliza los mecanismos
nativos de Android definidos por la implementación.

La protección debe considerar:

- Disponibilidad de hardware biométrico.
- Existencia de biometrías registradas.
- Compatibilidad del nivel de seguridad.
- Validación de la identidad vinculada.
- Protección mediante Android Keystore.
- Cancelación de la autenticación.
- Bloqueos y errores del mecanismo nativo.
- Cambios en el registro biométrico del dispositivo.
- Revocación o eliminación de la vinculación.

La aplicación no debe almacenar:

- Plantillas biométricas.
- Huellas digitales.
- Imágenes faciales.
- Contraseñas en texto plano.
- Tokens Firebase o Google en preferencias.
- Credenciales de autenticación en registros funcionales.

La autenticación biométrica del sistema operativo
no identifica cuál dedo o rostro específico
fue utilizado cuando existen varios registrados.

La vinculación debe mantenerse sujeta a los
controles de seguridad aprobados.

## Política temporal de sesiones

La política aprobada para los accesos privados
de las cuentas A y B establece:

- 60 minutos de inactividad en primer plano.
- 2 horas en segundo plano.
- 24 horas de vigencia absoluta de la sesión.

La actividad del usuario no debe extender
indefinidamente el límite absoluto establecido.

Los registros de sesión vencidos no deben
conceder acceso a contenido protegido.

La vinculación biométrica y la vigencia de la
autorización son conceptos diferentes.

Una vinculación biométrica existente no implica
que la sesión privada continúe vigente.

El desbloqueo biométrico no debe renovar
automáticamente una sesión vencida.

Las transiciones de sesión deben respetar
la separación entre las cuentas A y B.

## Protección de contenido privado

Los datos sensibles del seguimiento deben permanecer
protegidos antes de que exista autorización válida.

Durante el inicio, recuperación, cambio de cuenta,
bloqueo o expiración de sesión, la interfaz no debe
mostrar información del contexto anterior.

Las operaciones asíncronas no deben reintroducir
contenido privado después de la revocación del acceso.

Los errores de recuperación deben presentarse
mediante mensajes controlados.

No deben exponerse detalles internos de autenticación
ni información perteneciente a otra cuenta.

## Persistencia remota

Cloud Firestore constituye el servicio principal
de persistencia remota.

Los registros deben conservarse con controles
de autenticación, autorización e integridad.

La recuperación requiere que la identidad
correspondiente esté autenticada y autorizada.

Los datos deben permanecer aislados mediante
la estructura de propiedad y las reglas de acceso.

La persistencia remota no habilita mecanismos
funcionales de divulgación.

## Seguridad de Firestore

Las reglas de seguridad deben impedir el acceso
a registros pertenecientes a otros usuarios.

Las operaciones deben comprobar el UID autorizado.

Se deben validar los campos, tipos y restricciones
de integridad aplicables.

Las pruebas de reglas deberán comprobar tanto
accesos permitidos como intentos no autorizados.

Los servicios y repositorios deben respetar
las restricciones definidas en el modelo de datos.

## Comunicaciones y almacenamiento

Las comunicaciones remotas deben emplear
canales cifrados y autenticados.

La información persistida debe permanecer protegida
mediante los mecanismos de cifrado y control de acceso
proporcionados por la arquitectura seleccionada.

Los secretos de desarrollo y producción no deben
incorporarse al repositorio.

Los archivos locales utilizados para configuración,
pruebas o despliegue deben revisarse antes de publicarse.

## Firebase App Check

Firebase App Check constituye una protección
adicional para el acceso a servicios Firebase.

Durante desarrollo pueden utilizarse proveedores
de depuración controlados.

Los tokens Debug no deben incluirse en el código fuente,
commits, registros públicos ni APK de distribución.

En compilaciones de distribución deberán verificarse
las condiciones de compatibilidad y configuración
del proveedor de integridad seleccionado.

No debe asumirse que la distribución directa mediante
APK garantiza por sí sola la aceptación de App Check.

La autenticación, autorización y las reglas de
Firestore siguen siendo controles indispensables.

## Gestión de cuentas y operaciones destructivas

Las operaciones de cierre de sesión, desvinculación
biométrica y eliminación deben respetar la identidad
y el contexto correspondientes.

La eliminación de cuenta debe exigir la
reautenticación reciente que corresponda.

La biometría local no sustituye una operación
de reautenticación requerida por Firebase.

La eliminación de información debe cumplir
las reglas funcionales de confirmación e integridad.

## Manejo de errores

La aplicación debe gestionar de forma controlada:

- Falta de conectividad.
- Errores de autenticación.
- Sesiones vencidas.
- Revocación de autorización.
- Recuperaciones fallidas.
- Cancelaciones biométricas.
- Cambios de cuenta.
- Errores de almacenamiento.
- Fallos del mecanismo de protección local.

Un error no debe conceder acceso privado
ni provocar la visualización de datos ajenos.

No deben inventarse indicadores o resultados
cuando los registros no estén disponibles o
no pueda comprobarse su integridad.

## Control de dependencias

No deben incorporarse dependencias específicamente
destinadas a compartir, enviar o publicar información
de seguimiento sin una revisión de HU-18 y RF-20.

Las dependencias relacionadas con autenticación,
seguridad y persistencia deberán justificarse
según las necesidades técnicas del proyecto.

La implementación debe priorizar los servicios
compatibles con el plan Firebase Spark.

No se incorporarán Cloud Functions que requieran
contratar el plan Blaze.

## Pruebas de privacidad y seguridad

La verificación debe considerar:

- Autenticación y autorización.
- Separación de datos por UID.
- Anonimización de seguimientos.
- Protección de registros persistidos.
- Expiración de sesiones.
- Restauración de sesiones.
- Aislamiento entre las cuentas A y B.
- Bloqueo previo a la presentación de datos.
- Cancelación y errores biométricos.
- Reautenticación para operaciones destructivas.
- Eliminación y revocación de accesos.
- Integridad de registros.
- Prevención de divulgación.
- Ausencia de secretos en archivos publicados.

Se utilizarán datos ficticios durante las pruebas.

Los resultados deben mantenerse vinculados
a las Issues y Pull Requests correspondientes.

## Control de commits y Pull Requests

Antes de publicar cambios deberá verificarse:

- Que los archivos pertenezcan al alcance previsto.
- Que no existan secretos ni credenciales expuestas.
- Que no se incorporen datos reales de seguimiento.
- Que las dependencias añadidas estén justificadas.
- Que las pruebas relevantes hayan sido aprobadas.
- Que el análisis estático no presente incidencias.
- Que no existan cambios ajenos al incremento.
- Que la trazabilidad documental esté actualizada.

Las verificaciones de nombres de archivos no sustituyen
la revisión de secretos dentro de su contenido.

La integración debe seguir el procedimiento establecido
en `docs/SCRUM.md`.

## Verificación continua

El cumplimiento de estas salvaguardas debe revisarse
durante el desarrollo y antes de integrar cambios
relacionados con:

- Autenticación.
- Sesiones.
- Registros.
- Rutinas.
- Historial.
- Indicadores.
- Reportes.
- Navegación.
- Configuración de privacidad.
- Persistencia y recuperación.

Las salvaguardas no autorizan incorporar funciones
fuera del alcance académico del proyecto.