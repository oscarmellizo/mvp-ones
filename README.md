# Ones MVP (Monorepo)

Monorepo para el MVP **Ones**.

## Estructura

- `apps/ones_app` - Flutter (Android/iOS/Web)
- `services/ones-api` - Spring Boot API
- `contracts` - OpenAPI (source of truth)
- `infra` - CloudFormation + scripts
- `docs` - ADRs y diagramas

## Arquitectura (hexagonal)

### Backend (Spring Boot)

- **domain**: entidades/reglas
- **application**: casos de uso + puertos (interfaces)
- **adapters/inbound**: REST controllers, DTOs, mappers
- **adapters/outbound**: DynamoDB (y placeholders como S3)
- **configuration**: wiring Spring, security, CORS, AWS clients

### Frontend (Flutter)

- **domain**: entidades + repositorios (ports)
- **application**: use cases
- **adapters**: impls (HTTP, storage, etc.)
- **presentation**: UI

## Ejecutar localmente

### Backend (API)

Requisitos:

- Java 21
- Maven 3.9+
- Docker (opcional, para `dynamodb-local`)

Arranque con DynamoDB local (opcional):

```bash
# desde services/ones-api
docker compose up -d
```

Correr API:

```bash
# desde services/ones-api
mvn test
mvn spring-boot:run
```

Variables de entorno (placeholders, NO commitear secretos):

- `GOOGLE_CLIENT_ID` (requerida para validar `aud`)
- `ONES_EVENTS_TABLE` (default: `ones-events`)
- `AWS_REGION` (default: `us-east-1`)
- `DYNAMODB_ENDPOINT` (opcional para local, p.ej. `http://localhost:8000`)

Swagger/OpenAPI:

- `http://localhost:8080/swagger-ui.html`

### Frontend (Flutter)

Ver `apps/ones_app/README.md` (se agregará en siguientes pasos).

## Tests

- Backend: `mvn test` en `services/ones-api`
- Frontend: `flutter test` en `apps/ones_app`

## Deploy (AWS)

Ver `infra/README.md` (se agregará en siguientes pasos).

## Google Sign-In (resumen)

- Mobile: `google_sign_in`
- Web: `google_sign_in_web` (o GIS, documentado en el front)
- El front envía `Authorization: Bearer <Google ID Token>` al backend.
- El backend valida JWT y deriva `userId` desde claim `sub`.
