# Eliminación de cuentas dadas de baja — diseño

**Estado:** aprobado · **Rama prevista:** `feature/account-deletion` (después de cerrar `feature/firebase-auth`)

## Objetivo

Cumplir lo que promete el diálogo de baja y lo que exige App Store (eliminación real de la cuenta):
una cuenta dada de baja se puede reactivar durante 30 días; pasado ese plazo la persona recibe sus
fotos por correo y, 8 días después, todo se borra definitivamente.

## Decisiones tomadas

1. **Fotos por correo:** se mantiene. Al día 30 se envía un enlace de descarga que **dura 8 días**;
   después se borra todo, incluido el archivo de descarga.
2. **Datos de otros:** se borra todo aquello de lo que la persona es dueña: sus eventos **con todo
   su contenido** (incluidas las fotos que subieron sus invitados) y las fotos que ella subió en
   eventos de otras personas.
3. **Ejecución:** una regla diaria de **EventBridge Scheduler** llama a un endpoint interno del
   backend. Nada de `@Scheduled` dentro del servicio (con 0 instancias no corre, con varias corre
   duplicado).
4. **Apple:** al darse de baja (no en la tarea diaria) se revoca el token de Sign in with Apple.

## Línea de tiempo

| Día | Estado | Qué pasa |
|---|---|---|
| 0 | `DISABLED` | La persona se da de baja. Correo de baja (ya existe). Se revoca el token de Apple si aplica. Puede reactivar entrando de nuevo. |
| 30 | `DISABLED` → `CLOSED` | La tarea diaria genera el ZIP de sus fotos, envía el correo con el enlace (8 días) y bloquea la cuenta. Ya **no** se puede reactivar. |
| 38 | `CLOSED` → `DELETED` | La tarea diaria borra eventos, fotos, S3, el ZIP, el usuario de Firebase y deja una lápida mínima. |

Hoy el cierre al día 30 se calcula al vuelo (`AccountAccessService`). Con este diseño el estado
`CLOSED` se persiste, pero el cálculo al vuelo se mantiene como respaldo por si la tarea no corrió.

## Componentes

### Backend (`ones-api`)

- `POST /internal/accounts/lifecycle` (cadena `/internal/**` con autenticación básica existente).
  Ejecuta en orden las dos fases y devuelve un resumen (`closed`, `deleted`, `failed`).
  Se puede lanzar a mano para pruebas.
- **Fase cierre** (`CloseExpiredAccountsUseCase`): cuentas `DISABLED` con `disabledAt` ≤ ahora − 30 días.
  1. Genera `exports/{userId}/fotos.zip` en el bucket de fotos con sus fotos originales (las que
     subió en cualquier evento + las de sus eventos). Sin fotos → no hay ZIP y el correo lo dice.
  2. Envía el correo con un enlace prefirmado de 8 días (SES, mismo `AccountEmailService`).
  3. Marca `status=CLOSED`, `closedAt`, `purgeAfter = closedAt + 8 días`.
- **Fase borrado** (`PurgeClosedAccountsUseCase`): cuentas `CLOSED` con `purgeAfter` ≤ ahora.
  1. Eventos donde es dueña: borra fotos, likes, shortlinks, invitaciones, portadas y objetos S3 del evento.
  2. Fotos que subió en eventos ajenos: borra la foto, sus likes/shortlinks y sus objetos S3.
  3. Borra el ZIP de exportación.
  4. Anonimiza pagos y suscripciones (se conservan sin correo ni nombre).
  5. Borra el usuario de Firebase (`accounts:delete`, reutiliza `FirebaseIdentityToolkitClient`).
  6. Reemplaza la fila del usuario por una lápida (`status=DELETED`, `userId`, `deletedAt`, sin correo
     ni nombre) para que un token viejo no recree la cuenta y para auditoría.
- **Idempotencia:** cada paso se puede repetir; un fallo deja la cuenta en su estado y se reintenta
  al día siguiente. Se procesa por lotes con tope por ejecución.
- **Revocación Apple al darse de baja:** requiere el *authorization code* que entrega Apple al
  iniciar sesión; la app lo envía al backend al darse de baja y el backend llama a
  `appleid.apple.com/auth/revoke` con la clave de Sign in with Apple (nuevo secreto).

### Datos

- `photos` no tiene índice por quien subió la foto: se agrega GSI `byUploader`
  (`uploaderUserId`, `createdAt`). Hay que confirmar el nombre real del atributo y rellenarlo para
  fotos existentes.
- `users`: atributos nuevos `closedAt`, `purgeAfter`; índice o consulta para encontrar cuentas por
  estado y fecha (GSI `byStatus` con `status` + `disabledAt`/`purgeAfter`).
- Regla de ciclo de vida S3 en `exports/` a 9 días como red de seguridad.

### Infra

- `AWS::Scheduler::Schedule` diaria a las 03:00 America/Bogota con destino HTTP al ALB, usando
  una *connection* de EventBridge con la autenticación básica de `/internal`.
- Permisos del rol del backend para `s3:DeleteObject` en los buckets y el secreto de Apple.

### App

- Texto del diálogo de baja: "Pasados 30 días te enviaremos tus fotos por correo; el enlace dura
  8 días y después borraremos tu cuenta y todo su contenido definitivamente."
- Al darse de baja con Apple, enviar el *authorization code* para revocar.
- `ACCOUNT_CLOSED` ya muestra el mensaje correcto (rama `feature/firebase-auth`).

## Pruebas

- Unitarias de cada fase con reloj fijo: día 29 no cierra, día 30 cierra, día 37 no borra, día 38 borra.
- Repetir la tarea dos veces no duplica correos ni falla.
- Cuenta sin fotos, cuenta con eventos con invitados, fotos en eventos ajenos.
- Prueba local contra DynamoDB local + S3 simulado; prueba manual del endpoint en dev.

## Decisiones complementarias

- **Invitados:** no reciben aviso; las fotos del evento borrado simplemente desaparecen.
- **Pagos y suscripciones** (`subscription-payments`, `payment-profiles`, `user-subscriptions`,
  `mp-checkout-attempts`): se conservan por obligación contable, anonimizados (sin correo ni nombre;
  solo `userId` de la lápida).
- **Hora de la tarea:** todos los días a las 03:00 America/Bogota.
