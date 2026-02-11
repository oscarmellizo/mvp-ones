# Contracts (OpenAPI)

Este directorio contiene el contrato **source of truth** de la API.

- `openapi.yaml`: contrato OpenAPI 3.0

## Generar cliente Flutter

La generación se hace con **OpenAPI Generator**.

### Opción sin instalar nada (Docker)

```bash
# desde la raíz del repo
# genera/actualiza el package del cliente en packages/ones_api_client
./infra/scripts/generate-flutter-client.sh
```

Requisitos:

- Docker

### Opción sin Docker (JAR, recomendado en Windows si WSL tarda)

```powershell
# desde la raíz del repo
powershell -File .\infra\scripts\generate-flutter-client.ps1
```

El script descargará (si es necesario) `openapi-generator-cli` en `tools/` y generará el cliente en `packages/ones_api_client`.

Después de generar el cliente, ejecuta `build_runner` para producir los `*.g.dart` requeridos por `built_value`:

```powershell
powershell -File .\infra\scripts\build-ones-api-client.ps1
```

Notas:

- No se generan ni commitean secretos.
- Si cambias `openapi.yaml`, regenera el cliente.
