# Real-Time Gateway (WS) - Diseño y Handlers

## Objetivo
Canal WebSocket independiente (no tocar el WS de fotos) autenticado por token efímero emitido por ones-api, con conexiones por `userId` para entregar notificaciones en tiempo real.

## Flujo de Autenticación ($connect)
1. App móvil solicita `POST /v1/realtime/session` (requiere auth). Respuesta:
   - `token` (aleatorio base64url)
   - `expiresAt` (TTL ~120s)
2. La App abre el WebSocket de API Gateway con `?sessionToken=<token>`.
3. Lambda `$connect`:
   - Lee `sessionToken` del querystring.
   - Valida token en tabla `ws-sessions` y revisa expiración.
   - Registra `connectionId -> userId` en `ws-connections`.
   - Elimina el token (one-time use). Devuelve 200. Si inválido/expirado → 401.

## Desconexión ($disconnect)
- Lambda elimina `connectionId` de `ws-connections`. Idempotente, devuelve 200.

## Tablas DynamoDB
- `ones-dev-ws-sessions` (ya implementada)
  - PK: `token`
  - Atributos: `userId`, `createdAt`, `expiresAt`, `ttl` (epoch seconds)
- `ones-dev-ws-connections`
  - PK: `connectionId`
  - Atributos: `userId`, `createdAt`
  - GSI `byUserId`: PK `userId`, SK `createdAt` (permite listar conexiones activas por usuario)

## Componentes en ones-api
- Dominio:
  - `RealtimeSessionToken` y `RealtimeConnection`.
- Repositorios (DynamoDB Enhanced):
  - `RealtimeSessionTokensRepository` ⇢ `DynamoDbRealtimeSessionTokensRepository`.
  - `RealtimeConnectionsRepository` ⇢ `DynamoDbRealtimeConnectionsRepository`.
- Servicios:
  - `SessionValidationService`: valida token y registra/borra conexiones.
  - `WebsocketConnectionService`: orquesta `$connect/$disconnect` y consume token.
- Endpoints REST:
  - `POST /v1/realtime/session`: emite token efímero con TTL.

## Handlers Lambda
- `ConnectLambdaHandler`:
  - Entrada: evento API Gateway (WS). Extrae `connectionId` y `sessionToken`.
  - Construye `DynamoDbEnhancedClient` con `AWS_REGION`.
  - Usa tablas: `ONES_WS_SESSIONS_TABLE` y `ONES_WS_CONNECTIONS_TABLE` (fallback a defaults de dev).
  - Llama a `WebsocketConnectionService.connect()`.
  - Respuesta: `{ statusCode: 200|401 }`.
- `DisconnectLambdaHandler`:
  - Entrada: evento con `connectionId`.
  - Borra conexión vía `WebsocketConnectionService.disconnect()`.
  - Respuesta: `{ statusCode: 200 }`.

## Envío en tiempo real (futuro)
- Tabla `ws-connections` + GSI `byUserId` permite buscar conexiones del usuario.
- Con `ApiGatewayManagementApiClient` (ya en dependencias) publicar a cada `connectionId`.
- Añadir retries/backoff/registro de métricas.

## Variables de Entorno
- `AWS_REGION`: región AWS (requerida por SDK v2).
- `ONES_WS_SESSIONS_TABLE`: nombre de la tabla de sesiones (opcional, default dev).
- `ONES_WS_CONNECTIONS_TABLE`: nombre de la tabla de conexiones (opcional, default dev).

## Observabilidad y Escalabilidad
- Conexiones O(1) por PK y queries por GSI.
- Tokens efímeros con TTL reducen superficie de ataque.
- Añadir métricas: intentos $connect 2xx/4xx/5xx, conexiones activas por userId, expiraciones de token.
- Considerar TTL de seguridad en `ws-connections` (p.ej. 24h) para limpieza si falla `$disconnect`.
