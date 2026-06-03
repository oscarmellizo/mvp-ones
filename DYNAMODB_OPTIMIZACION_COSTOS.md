# Optimización de costos DynamoDB (Ones)

## Cambios implementados (mejoras ya hechas)

### 1) Menos lecturas repetidas (caching en el backend)

- **Traducciones**
  - Cache in-memory (Caffeine / Spring Cache) **sin expiración** por `languageCode`.
  - El cache **solo se invalida** cuando:
    - Un admin hace `upsert`/`delete` de una traducción.
    - Un admin llama endpoints manuales de cache.
  - Endpoints admin:
    - `POST /v1/admin/translations/cache/evict?languageCode=...` (o sin `languageCode` para evict total)
    - `POST /v1/admin/translations/cache/refresh?languageCode=...` (evict + warm)

- **Photos (listado por evento, primera página)**
  - Cache de corta duración (TTL) para la **primera página** (`nextToken` vacío) por `eventId`.
  - Objetivo: reducir picos de RCU cuando varios clientes piden la misma lista repetidamente.

- **Invitations (listado por evento)**
  - Cache de corta duración (TTL) por `eventId`.

> Nota: estos caches son **in-memory por instancia**. Si hay múltiples tasks en ECS, cada una tendrá su propio cache.

### 2) Evitar Scan “silencioso” en traducciones

- Se ajustó el repositorio DynamoDB de traducciones para:
  - Usar el GSI `LanguageCodeIndex` cuando está disponible.
  - **No usar Scan** como fallback por defecto (para evitar costos inesperados).
  - Emitir métrica cuando se usa fallback Scan (si se habilita).

### 3) Provisioned + AutoScaling en DynamoDB

- Se cambió el modo de facturación de estas tablas a **PROVISIONED** con **Application Auto Scaling**:
  - `photos` + GSI `byEventId`
  - `invitations` + GSI `byEventId`
  - `translations` + GSI `LanguageCodeIndex`

- Se removió el gating que lo hacía solo para `dev`; ahora aplica para **dev/stage/prod**.

> Importante: en PROVISIONED el costo base depende del **MinCapacity / ProvisionedThroughput**.

## Qué falta / pasos pendientes para bajar costo de forma verificable

### 1) Deploy de infraestructura (CloudFormation)

- Aplicar el update del stack backend para que:
  - Las tablas pasen a PROVISIONED.
  - Se creen los ScalableTargets/Policies.

### 2) Verificación post-deploy (imprescindible)

- Confirmar en CloudWatch (por tabla y GSI):
  - `ConsumedReadCapacityUnits` / `ConsumedWriteCapacityUnits`
  - `ProvisionedReadCapacityUnits` / `ProvisionedWriteCapacityUnits`
  - `ReadThrottleEvents` / `WriteThrottleEvents`
  - Latencia en endpoints críticos

- Ajustar:
  - **MinCapacity** (bajar si el consumo real es muy bajo, para reducir costo)
  - **TargetValue** (ej. 70%)
  - **ScaleInCooldown / ScaleOutCooldown**

### 3) Alinear queries a índices (para evitar reads caros)

- Validar que los listados de alto volumen siempre sean `Query` y no `Scan`.
- Si aparece `Scan`, arreglar índices o access patterns.

### 4) Medición de impacto en costos

- Medir el costo diario real:
  - DynamoDB: modo PROVISIONED (RCU/WCU mínimos) + picos por autoscaling.
  - Comparar contra baseline anterior.

## Riesgos / consideraciones

- Aplicar PROVISIONED en prod/stage puede:
  - **Reducir** costo si el tráfico es estable y el baseline se ajusta bien.
  - **Aumentar** costo si el `MinCapacity` queda alto para el consumo real.
- Cache in-memory no es compartido entre instancias.
  - Aun así reduce costo porque cada instancia evita lecturas repetidas dentro del TTL.

## Checklist rápido antes de deploy

- [ ] Confirmar valores de `ProvisionedThroughput` (RCU/WCU base) por ambiente.
- [ ] Confirmar `MaxCapacity` suficiente (no afecta costo base pero sí el techo de escalamiento).
- [ ] Confirmar que no haya throttling esperado (especialmente en prod).
