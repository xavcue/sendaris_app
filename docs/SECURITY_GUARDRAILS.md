# Salvaguardas de privacidad y seguridad de Sendaris

## Finalidad

Este documento establece restricciones técnicas transversales para mantener la
información de seguimiento dentro de la finalidad definida para Sendaris.

## Prohibición de divulgación funcional

Sendaris no debe incorporar funcionalidades destinadas a:

- compartir registros de seguimiento;
- enviar registros o reportes a terceros;
- publicar registros o reportes;
- enviar información mediante correo electrónico desde la aplicación;
- enviar información mediante SMS o mensajería;
- integrar redes sociales para divulgar información del seguimiento;
- ofrecer botones o menús de compartir relacionados con registros o reportes.

Estas restricciones corresponden a HU-18 y RF-20.

## Comunicaciones técnicas permitidas

Las comunicaciones externas están permitidas únicamente cuando son necesarias
para la operación técnica y segura de la aplicación, incluyendo:

- Firebase Authentication;
- Cloud Firestore;
- Firebase App Check;
- persistencia remota;
- recuperación segura de información;
- sincronización técnica requerida por la arquitectura.

La existencia de estas comunicaciones técnicas no constituye una funcionalidad
de publicación, envío o compartición disponible para el usuario.

## Persistencia remota

El almacenamiento remoto no habilita por sí mismo ninguna función para compartir,
publicar, enviar o divulgar registros o reportes.

Los datos deben permanecer sujetos a autenticación, autorización, reglas de
seguridad y separación lógica entre usuarios.

## Control de dependencias

No deberán incorporarse dependencias específicamente orientadas a compartir,
correo, SMS o mensajería de información del seguimiento sin una revisión previa
del cumplimiento de HU-18.

## Verificación continua

El cumplimiento de esta política deberá revisarse durante el desarrollo de los
módulos de historial, visualización y reportes, así como antes de finalizar el
proyecto.