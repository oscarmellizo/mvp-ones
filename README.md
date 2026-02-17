# Ones MVP (Monorepo)

Monorepo para el MVP **Ones**.

La idea del repo es que un equipo pueda:

- Desarrollar **backend (Spring Boot)** y **frontend (Flutter)** en un mismo lugar.
- Mantener el contrato HTTP como **source of truth** vía **OpenAPI**.
- Desplegar y destruir infraestructura en AWS con **CloudFormation** + **GitHub Actions (OIDC)**.

---

## Arquitectura (alto nivel)

Flujo típico (producción / demo):

- Flutter Web (CloudFront)
  - Hace login con Google y obtiene `idToken`.
  - Llama al backend con `Authorization: Bearer <idToken>`.
- Spring Boot API (ECS Fargate detrás de ALB)
  - Valida JWT de Google (`aud`, firma, etc.).
  - Usa el claim `sub` como `userId` (owner).
  - Persiste y consulta datos en DynamoDB.

Infra (AWS):

- **CloudFormation stacks**
  - `ones-bootstrap-oidc`: proveedor OIDC + rol de deploy para GitHub Actions.
  - `ones-backend`: ECR + ECS/Fargate + ALB + DynamoDB + VPC básica.
  - `ones-web`: S3 privado + CloudFront + Origin Access Control.

---

## Arquitectura (hexagonal / ports & adapters)

### Backend (`services/ones-api`)

Objetivo: separar lógica de negocio de frameworks y de I/O.

- **domain**
  - Entidades y reglas de negocio.
  - *No* depende de Spring / AWS / HTTP.
- **application**
  - Casos de uso.
  - Define puertos (interfaces) que la infraestructura implementa.
- **adapters**
  - **inbound**: controllers REST, DTOs, mappers.
  - **outbound**: repositorios DynamoDB, etc.
- **configuration**
  - Wiring con Spring (beans).
  - Security (Resource Server JWT), CORS, clientes AWS.

### Frontend (`apps/ones_app`)

Objetivo: UI desacoplada de HTTP/storage.

- **domain**
  - Entidades y contratos (repositorios/ports).
- **application**
  - Use cases.
- **adapters**
  - Implementaciones concretas (HTTP client, auth, storage).
- **presentation**
  - UI, controllers/view-models.

---

## Estructura del repo (por carpeta)

- **`apps/ones_app`**
  - App Flutter (Android/iOS/Web).
  - Lee config vía `--dart-define`.
  - Integra Google Sign-In y luego consume la API.

- **`services/ones-api`**
  - API Spring Boot.
  - Autenticación: valida Google ID Token (JWT) como resource server.
  - Persistencia: DynamoDB.
  - Incluye `Dockerfile` para build/push a ECR.

- **`contracts`**
  - `openapi.yaml`: **contrato HTTP** (source of truth).
  - Se usa para generar el cliente de Flutter.

- **`packages/ones_api_client`**
  - Cliente Dart generado desde OpenAPI (generator `dart-dio`).
  - Se regenera cuando cambia el contrato.

- **`infra`**
  - Infraestructura como código:
    - `cloudformation/`: templates.
    - `scripts/`: scripts para generar/build del cliente Flutter desde OpenAPI.

- **`.github/workflows`**
  - CI/CD y automatizaciones (deploy/destroy infra y deploy apps).

- **`docs/adr`**
  - ADRs (decisiones de arquitectura). Ej: `0001-architecture.md`.

---

## Contrato API (OpenAPI)

Archivo: `contracts/openapi.yaml`.

Endpoints principales:

- `GET /health`
  - Health-check para ALB/ECS.
- `GET /v1/events`, `POST /v1/events`, `GET /v1/events/{id}`
  - Requieren `bearerAuth` (Google ID Token).

---

## Scripts (por qué existen y cuándo usarlos)

Carpeta: `infra/scripts`.

- **`generate-flutter-client.ps1` / `generate-flutter-client.sh`**
  - Genera `packages/ones_api_client` desde `contracts/openapi.yaml`.
  - Preferencia:
    - Si Docker está disponible, usa la imagen `openapitools/openapi-generator-cli`.
    - Si no, descarga el JAR del generator a `tools/` y ejecuta con `java -jar`.

- **`build-ones-api-client.ps1` / `build-ones-api-client.sh`**
  - Ejecuta `dart run build_runner build --delete-conflicting-outputs` en `packages/ones_api_client`.
  - Útil cuando el generator produce modelos con `json_serializable`/builders.

---

## Ejecutar localmente

### Requisitos

- Java **17** (ver `services/ones-api/pom.xml`).
- Docker (opcional, para `dynamodb-local`).
- Flutter (stable) + Dart.

### Backend (API)

Opcional: levantar DynamoDB local.

```bash
# desde services/ones-api
docker compose up -d
```

Ejecutar tests y app:

```bash
# desde services/ones-api
./mvnw -q test
./mvnw spring-boot:run
```

Variables de entorno (no commitear secretos):

- `GOOGLE_CLIENT_ID`:
  - Client ID esperado para validar el `aud` del token.
- `ONES_EVENTS_TABLE`:
  - default `ones-events`.
- `AWS_REGION`:
  - default `us-east-1`.
- `DYNAMODB_ENDPOINT`:
  - solo local, ejemplo `http://localhost:8000`.

Swagger:

- `http://localhost:8080/swagger-ui.html`

### Frontend (Flutter)

Ejemplo para web local:

```bash
# desde apps/ones_app
flutter run -d chrome \
  --dart-define=ONES_ENV=dev \
  --dart-define=ONES_API_BASE_URL=http://localhost:8080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

---

## CI/CD (GitHub Actions) y por qué existen

Workflows en `.github/workflows`:

- **`ci.yml`**
  - Backend: `./mvnw test`
  - Frontend: `flutter test`
  - Corre en push a `main` y manual (`workflow_dispatch`).

- **Bootstrap OIDC**
  - `deploy-infra-bootstrap-oidc.yml`
  - `deploy-infra-bootstrap-oidc-validated.yml` (valida status + outputs)
  - Mantienen el rol OIDC con permisos para crear/borrar stacks y operar servicios.

- **Infra Backend**
  - `deploy-infra-backend.yml`: crea/actualiza el stack `ones-backend`.
  - `destroy-infra-backend.yml`: destruye `ones-backend` de forma segura:
    - scale a 0 en ECS
    - vacía imágenes de ECR
    - borra el stack

- **App Backend**
  - `deploy-backend-app.yml`:
    - build de Docker
    - push a ECR
    - `ecs update-service` con `desired-count 1` + `--force-new-deployment`

- **Infra Web**
  - `deploy-infra-web.yml`: crea/actualiza el stack `ones-web`.
  - `destroy-infra-web.yml`: vacía el bucket y borra el stack (idempotente).

- **App Web**
  - `deploy-web-app.yml`:
    - build de Flutter Web
    - upload a S3
    - invalidación de CloudFront

---

## Infraestructura en AWS (CloudFormation)

Templates:

- **`infra/cloudformation/bootstrap-oidc.yml`**
  - Crea el `AWS::IAM::OIDCProvider` para GitHub.
  - Crea el rol `ones-github-actions-deploy-role` con permisos para:
    - CloudFormation
    - S3 + CloudFront
    - ECR
    - ECS/ELB/EC2
    - DynamoDB
    - CloudWatch Logs

- **`infra/cloudformation/backend.yml`**
  - DynamoDB (`ones-events` por default)
  - ECR repo para la imagen del backend
  - VPC/subnets públicas
  - ALB + Target Group (health check en `/health`)
  - ECS cluster + task definition + service
  - `HealthCheckGracePeriodSeconds: 120` para evitar flapping en despliegues.

- **`infra/cloudformation/web.yml`**
  - S3 privado (sin nombre fijo, para recreación simple)
  - CloudFront distribution
  - Origin Access Control (nombre único por stack)
  - Bucket policy con `AWS:SourceArn` restringido al distribution.

---

## Configuración requerida en GitHub (Variables)

En **GitHub → Settings → Secrets and variables → Actions → Variables**:

- `AWS_GITHUB_OIDC_ROLE_ARN`
  - ARN del rol del stack `ones-bootstrap-oidc`.
- `AWS_REGION` (opcional, default `us-east-1`)
- `STACK_PREFIX` (opcional, default `ones`)
- `GOOGLE_CLIENT_ID`
  - Backend valida `aud` con este valor.
- `GOOGLE_WEB_CLIENT_ID`
  - Se inyecta al build de Flutter Web.
- `ONES_EVENTS_TABLE` (opcional, default `ones-events`)

---

## Google OAuth (Web) - checklist

Para evitar `redirect_uri_mismatch` en Web:

- En tu **OAuth Client ID (Web application)** en Google Cloud:
  - Agregar **Authorized JavaScript origins** con el dominio CloudFront:
    - `https://<TU_DISTRIBUTION>.cloudfront.net`

---

## Modo “trabajo algunos días” (bajar costos)

El repo está preparado para **crear y destruir** la infra según lo necesites.

Rutina sugerida:

- Cuando vas a trabajar:
  - `Deploy Infra (Bootstrap OIDC) [Validated]` (solo si cambiaste permisos)
  - `Deploy Infra (Backend)`
  - `Deploy Backend App`
  - `Deploy Infra (Web)`
  - `Deploy Web App`

- Cuando terminas:
  - `Destroy Infra (Web)`
  - `Destroy Infra (Backend)`

Nota: esto borra recursos y datos. Para etapa MVP esto es aceptable.

---

## Troubleshooting (problemas comunes)

- **CloudFormation EarlyValidation / ResourceExistenceCheck**
  - Causa: recursos con nombres fijos quedaron “huérfanos” (ej. repos ECR).
  - Solución: destruir con workflows `destroy-*` o evitar nombres fijos.

- **Rollback trabado en CloudFront OriginAccessControl**
  - Causa: faltaban permisos de delete/tag en el rol OIDC.
  - Solución: redeploy del stack `ones-bootstrap-oidc`.

- **`redirect_uri_mismatch` en Google Sign-In Web**
  - Causa: falta `Authorized JavaScript origin` del dominio CloudFront.
  - Solución: registrar `https://<distribution>.cloudfront.net` en Google Cloud.

- **ALB devuelve 502/503 durante deploy**
  - Causa: Spring Boot tarda en arrancar y falla health check.
  - Solución: `HealthCheckGracePeriodSeconds` (ya incluido en el template).

---

## Referencias rápidas

- Backend local: `services/ones-api/README.md`
- Frontend local: `apps/ones_app/README.md`
- Contrato: `contracts/openapi.yaml`
