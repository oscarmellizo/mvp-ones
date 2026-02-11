# ADR 0001: Monorepo + Hexagonal + AWS (ECS Fargate / DynamoDB / S3 / CloudFront) + Google ID Token

## Contexto

Necesitamos un MVP con front (Flutter) + back (Spring Boot) + infra (AWS) con despliegue repetible.

## Decisión

- Usar **monorepo** con:
  - `apps/` (front)
  - `services/` (back)
  - `contracts/` (OpenAPI)
  - `infra/` (CloudFormation + scripts)
- Usar **arquitectura hexagonal (ports & adapters)** en front y back.
- Infra MVP en AWS:
  - **ECS Fargate** para el backend (contenedor)
  - **DynamoDB** como base no relacional
  - **S3** para media y hosting del front web
  - **CloudFront** como CDN para el front web
- Autenticación inicial con **Google Sign-In**:
  - El frontend obtiene **Google ID Token**
  - El backend lo valida como JWT (Resource Server)
  - El `userId` se deriva del claim **`sub`**
  - No usar Cognito en el MVP

## Motivación

- **Monorepo**: versionado consistente entre front/back/contracts/infra; facilita cambios coordinados.
- **Hexagonal**: separa reglas y casos de uso del framework (Flutter/Spring/AWS SDK); mejora testabilidad.
- **ECS Fargate**: reduce operación de servidores; despliegue por imagen.
- **DynamoDB**: escala y reduce operación; encaja con modelos por usuario + GSI.
- **S3 + CloudFront**: hosting estático simple y barato.
- **Google ID Token**: rápida salida a producción sin administrar users/passwords; suficiente para MVP.

## Consecuencias

- Se requiere administrar `GOOGLE_CLIENT_ID` por ambiente para validar `aud`.
- Los contratos OpenAPI se tratan como **source of truth**.
- Infra se despliega por CloudFormation; scripts y CI automatizan el flujo.
