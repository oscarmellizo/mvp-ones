# Cambios realizados: Galería de fotos, WebSocket (tiempo real) e i18n

Este documento explica **qué se cambió**, **por qué**, y **cuáles son las ventajas y desventajas**. Está escrito para alguien que no necesariamente es experto en arquitectura o AWS/Flutter.

## 1) Problemas originales (por qué se necesitaba cambiar)

### 1.1 Usuarios viendo eventos/fotos que no les corresponden
- **Síntoma**
  - Un usuario podía ver información de eventos a los que **no estaba invitado**.
- **Riesgo**
  - Es un problema de **seguridad y privacidad**.

### 1.2 Mezcla de fotos entre eventos (condiciones de carrera)
- **Síntoma**
  - Si el usuario cambia rápido entre eventos o se disparan varias cargas, podían aparecer fotos del evento A dentro del evento B.
- **Causa típica**
  - En apps móviles es común disparar requests asíncronos; si llega tarde una respuesta “vieja”, puede pisar el estado actual.

### 1.3 UX mala durante la subida: “desaparece” la foto al terminar el upload
- **Síntoma**
  - Al subir la foto, se muestra progreso.
  - Pero cuando el upload termina, el backend todavía está generando thumbnails (S y M) y marcando la foto como `ready`.
  - Ese lapso se percibía como que la foto “se pierde” unos segundos.

### 1.4 i18n: usuarios normales viendo claves sin traducir
- **Síntoma**
  - Usuarios no-admin obtenían llaves tipo `home.title` en lugar de la traducción.
- **Causa**
  - El endpoint de traducciones estaba bajo rutas/admin o permisos no adecuados para usuarios normales.

### 1.5 Rendimiento: cargar fotos de a 9 (paginación)
- **Objetivo**
  - Evitar pedir 50/100 fotos de golpe.
  - Cargar “por páginas” de 9 y luego pedir la siguiente página cuando el usuario baja.

---

## 2) Cambios en Backend API (Java / Spring)

### 2.1 Autorización estricta de acceso a eventos
- **Qué se hizo**
  - Se reforzó la lógica para que un usuario solo pueda obtener un evento si:
    - Es el **owner**, o
    - Tiene una **invitación aceptada**.
  - Esto se aplica cuando se consulta el evento para ver detalles/fotos.
- **Cómo funciona (en simple)**
  - El backend recibe tu identidad (claims del token) y el `eventId`.
  - Busca el evento.
  - Si tú eres el owner → OK.
  - Si no, busca una invitación `accepted` para tu email en ese evento → si no existe, se comporta como “no encontrado”.
- **Ventajas**
  - **Seguridad real** (no depende de que el cliente se “porte bien”).
  - Reduce exposición de datos.
- **Desventajas**
  - Más validaciones por request.
  - Si hubiera bugs en invitaciones/estados, puede causar “falsos negativos” (usuario con acceso pero invitación mal guardada).

### 2.2 No devolver thumbnails hasta que la foto esté `ready`
- **Qué se cambió**
  - En el listado de fotos (`listV2`), las URLs `smallUrl` y `mediumUrl` solo se devuelven cuando `status == "ready"`.
- **Por qué**
  - Cuando se sube una foto, la miniatura aún no existe. Si el cliente intenta descargarla, obtiene errores/links rotos.
- **Ventajas**
  - Evita “imágenes rotas” y reintentos inútiles.
  - La UI puede distinguir claramente entre:
    - `originalUrl` disponible
    - thumbnails no disponibles todavía
- **Desventajas**
  - Si la UI no maneja `null`, podría romperse; por eso se manejó el estado de “processing” en el cliente.

### 2.3 i18n: nuevo endpoint para usuarios normales
- **Qué se hizo**
  - Se creó `GET /v1/translations?languageCode=...`.
  - Se ajustó seguridad para que sea **authenticated** (usuario logueado), sin requerir rol admin.
- **Ventajas**
  - Usuarios normales obtienen traducciones correctamente.
  - Separa responsabilidades: 
    - Admin mantiene endpoints de administración.
    - App normal usa endpoint de lectura.
- **Desventajas**
  - Mayor superficie de API (más endpoints a mantener).

---

## 3) Cambios en Flutter (App móvil)

### 3.1 i18n en Flutter: cache-first + endpoint correcto
- **Qué se cambió**
  - El servicio de traducciones (`translations_service.dart`) ahora:
    - Lee primero de cache local.
    - Luego refresca desde `GET /v1/translations`.
  - Se corrigió el uso del cliente HTTP (`Dio`) y el interceptor de Bearer.
- **Ventajas**
  - La app “arranca” más rápido y muestra traducciones sin depender de la red.
  - Menos probabilidad de ver llaves sin traducir.
- **Desventajas**
  - Manejar cache implica lógica adicional (posibles des-sincronizaciones si no hay estrategia de invalidación).

### 3.2 Integridad de galería: protección contra respuestas viejas (race conditions)
- **Qué se hizo**
  - En `PhotosGalleryController` se usa un contador interno (`_requestEpoch`).
  - Cada request incrementa el epoch.
  - Cuando llega la respuesta, solo se aplica si el epoch coincide con el último.
- **Ventajas**
  - Evita que fotos de otro evento “pisen” el estado actual.
  - Soluciona un bug muy común en apps con requests asíncronos.
- **Desventajas**
  - Si hay muchos cambios rápidos, algunas respuestas legítimas se descartan (pero es lo correcto en este caso).

### 3.3 Paginación: cargar en lotes de 9
- **Qué se hizo**
  - `PhotosGalleryController.refresh()` y `loadMore()` llaman al API con `limit: 9`.
- **Ventajas**
  - Mejor performance y menor consumo de datos.
  - Mejor escalabilidad (menos carga en backend por usuario).
- **Desventajas**
  - La UI debe manejar “cargar más” (scroll + triggers).

### 3.4 Estado local de subidas: pending/uploading/processing
- **Qué se hizo**
  - Se mantiene una DB local (SQLite) para la cola de uploads.
  - Estados:
    - `pending`: en cola
    - `uploading`: se está subiendo
    - `processing`: el servidor ya recibió pero aún genera thumbnails
  - Se muestra progreso % usando `onSendProgress`.
- **Ventajas**
  - UX consistente: el usuario ve el progreso real.
  - Si la app se cierra, al volver puede rehidratar la cola.
- **Desventajas**
  - Complejidad adicional (sincronización entre estado local y remoto).

---

## 4) WebSocket para “foto lista” (`photo.ready`)

### 4.1 ¿Cuál es la idea?
En lugar de que el móvil esté “preguntando” cada X segundos si la foto ya está lista, el servidor **empuja** un evento en tiempo real cuando termina el procesamiento.

- **Evento**: `photo.ready`
- **Payload** (simplificado):
  - `eventId`
  - `photoId`

### 4.2 Infraestructura AWS agregada
Se agregó infraestructura en `infra/cloudformation/backend/all.yml`:
- **API Gateway WebSocket API**
  - Rutas: `$connect`, `$disconnect`, `subscribe`, `unsubscribe`.
- **DynamoDB**
  - Tabla de conexiones (connectionId → TTL)
  - Tabla de suscripciones (eventId + connectionId → TTL)
- **Lambda handler** para WebSocket
  - Maneja connect/disconnect/subscribe/unsubscribe.

#### Ventajas
- Tiempo real real.
- Menos polling = menos tráfico y menos costos.
- Escala horizontalmente (API Gateway y DynamoDB son servicios administrados).

#### Desventajas
- Aumenta la complejidad de infraestructura.
- Se debe gestionar expiración de conexiones (TTL) y desconexiones.

### 4.3 Cambio importante de seguridad: se eliminó Google `tokeninfo` dentro del WebSocket Lambda
- **Qué estaba**
  - En una versión anterior, el WS Lambda validaba el token llamando a Google `tokeninfo`.
- **Qué se cambió**
  - Se eliminó esa llamada externa.
  - En `$connect` solo se exige que exista token.
  - La autorización real se hace en `subscribe` llamando al backend:
    - `GET /v1/events/{eventId}` con `Authorization: Bearer <token>`.
  - Si el backend responde “OK”, recién ahí se guarda la suscripción.

#### Ventajas (muy importantes para escalabilidad)
- **No hay dependencia externa** en tiempo real.
- Evita latencias variables de Google.
- Evita throttling/limitaciones de un tercero.
- Mejor para miles de conexiones concurrentes.

#### Desventajas
- `$connect` no valida “a fondo” el token.
  - Pero el sistema sigue siendo seguro porque:
    - Sin `subscribe` autorizado no se recibe nada.
    - Y la publicación de eventos se hace por suscripciones.

### 4.4 Publicación del evento desde la Lambda de thumbnails
- **Qué se hizo**
  - Cuando el procesamiento termina (thumbnails creados y backend marcado como ready), la Lambda publica `photo.ready` a todas las conexiones suscritas a ese `eventId`.

#### Ventajas
- La UI puede actualizar inmediatamente.

#### Desventajas
- Si hay bugs en suscripciones, el evento puede no llegar (aunque la foto igual quedará lista; la UI se actualizará al próximo refresh manual/paginación).

### 4.5 Cliente WebSocket en Flutter
- **Nuevo controlador**: `PhotosWsController`.
- **Conexión**
  - Usa `web_socket_channel`.
  - Conecta a `wss://.../dev?token=<idToken>`.
- **Suscripción**
  - Envía: `{ action: 'subscribe', eventId, token }`.
- **Integración**
  - Se inyecta por `Provider` en `app.dart`.
  - En la pantalla del evento (`event_detail_page.dart`) se hace subscribe al `eventId` actual.
  - Al recibir `photo.ready`, se hace un `refresh()` del gallery controller (con debounce).

#### Ventajas
- UX: al terminar el procesamiento, la foto aparece sin que el usuario haga nada.
- Menos “vacíos” visuales tras upload.

#### Desventajas
- WebSocket puede desconectarse (red móvil). Se necesita reconexión (la base ya está).
- La app debe tener configurada la URL WS (`photosWsUrl`).

---

## 5) Configuración: `photosWsUrl`

### 5.1 Dónde se configura
En Flutter se agregó `photosWsUrl` a `AppConfig`.

Puedes configurarlo de dos maneras:
- En `assets/config/app_config.json` agregando:
  - `"photosWsUrl": "wss://..."`
- O en runtime con:
  - `--dart-define=ONES_PHOTOS_WS_URL=wss://...`

### 5.2 Output en CloudFormation
Se agregó un output `PhotosWsUrl` para poder copiar/pegar el endpoint correcto del stack.

---

## 6) Resumen de ventajas vs desventajas (alto nivel)

### Ventajas
- **Seguridad**: no se filtran eventos/fotos a usuarios no autorizados.
- **Integridad UI**: no se mezclan fotos entre eventos por requests tardíos.
- **Performance**: paginación de 9 reduce latencia y costo.
- **UX upload**: progreso real + estado “processing” + actualización en tiempo real cuando queda `ready`.
- **Escalabilidad**: WebSocket sin dependencias externas en caliente; DynamoDB + API Gateway son servicios administrados.

### Desventajas
- **Complejidad**: se agrega infraestructura (WS + DynamoDB + Lambda).
- **Operación**: hay que monitorear conexiones, errores y eventos (idealmente logs/metrics).
- **Configuración**: hay que setear correctamente `photosWsUrl`.

---

## 7) Qué falta / próximos pasos recomendados
- **Configurar `photosWsUrl`** en `assets/config/app_config.json` o `dart-define`.
- **Desplegar CloudFormation** y verificar el output `PhotosWsUrl`.
- **Prueba manual**
  - Subir foto
  - Ver progreso
  - Al terminar, debe quedar el placeholder mientras está `processing`
  - Cuando llega `photo.ready`, debe refrescar y mostrarse la thumbnail

