# ones-api (Spring Boot)

API del MVP Ones.

## Ejecutar local

```bash
mvn test
mvn spring-boot:run
```

Opcional DynamoDB local:

```bash
docker compose up -d
```

## Variables de entorno

- `GOOGLE_CLIENT_ID` (requerida)
- `ONES_EVENTS_TABLE` (default `ones-events`)
- `AWS_REGION` (default `us-east-1`)
- `DYNAMODB_ENDPOINT` (opcional para local)

## Swagger

- `http://localhost:8080/swagger-ui.html`
