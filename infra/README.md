# Infra

Se agregará CloudFormation + scripts de deploy en siguientes pasos.

Por ahora:

- `scripts/generate-flutter-client.*` genera el cliente Flutter desde `contracts/openapi.yaml`.

## Observabilidad (ECS Fargate + ALB + AMP + Prometheus endpoint)

El backend (`services/ones-api`) expone métricas Prometheus en:

- `GET /actuator/prometheus`

Este endpoint está protegido con Basic Auth (ver `ONES_ACTUATOR_BASIC_USERNAME` / `ONES_ACTUATOR_BASIC_PASSWORD`).

### Flujo recomendado

- `ones-api` corre en ECS Fargate detrás de un ALB.
- Un sidecar `aws-otel-collector` (ADOT) en la misma Task scrapea `http://127.0.0.1:8080/actuator/prometheus` usando Basic Auth.
- El collector hace `remote_write` a Amazon Managed Prometheus (AMP).
- Grafana self-hosted se conecta a AMP como datasource Prometheus (SigV4).

### Secrets requeridos

- `ones/<env>/openai-api-key`
- `ones/<env>/actuator-basic-auth` con JSON:
  - `{ "username": "...", "password": "..." }`

### Métricas clave

El backend incrementa un counter cuando cae en fallback a Scan de DynamoDB:

- `ones_dynamodb_scan_fallback_total{repository="users",operation="findByEmail"}`
- `ones_dynamodb_scan_fallback_total{repository="invitations",operation="listByEventId"}`

Ejemplos PromQL:

- `sum by (repository, operation) (ones_dynamodb_scan_fallback_total)`
- `sum by (repository, operation) (rate(ones_dynamodb_scan_fallback_total[5m]))`

### Flags operacionales

- `ONES_DYNAMODB_FAIL_ON_SCAN_FALLBACK=true`
  - En producción, cuando ya existen los GSIs requeridos, evita degradación silenciosa a Scan.
