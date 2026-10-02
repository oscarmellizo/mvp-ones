# Eliminación de cuentas dadas de baja — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una tarea diaria (03:00 America/Bogota) cierra las cuentas con más de 30 días de baja enviando sus fotos por correo (enlace de 8 días) y, 8 días después, borra definitivamente todo lo que la cuenta posee.

**Architecture:** EventBridge Scheduler invoca una lambda mínima que hace `POST /internal/accounts/lifecycle` (basic auth) al ALB. El backend responde 202 y ejecuta en segundo plano dos casos de uso idempotentes: `CloseExpiredAccountsUseCase` (ZIP + correo + `CLOSED`) y `PurgeClosedAccountsUseCase` (eventos, fotos, likes, invitaciones, ZIP, pagos anonimizados, usuario de Firebase, lápida `DELETED`). El enlace del correo apunta a `GET /v1/account-exports/{token}` en el API, que valida el token y redirige a un enlace firmado de S3 de 5 minutos.

**Tech Stack:** Spring Boot 3.3.6 / Java 17, AWS SDK v2 (DynamoDB enhanced, S3, SESv2), JUnit 5 + Mockito, CloudFormation, Python 3.12 (lambda), Flutter (firebase_auth ^6.7.0).

**Spec:** `docs/superpowers/specs/2026-10-02-account-deletion-design.md`

**Rama:** `feature/account-deletion` (creada desde `feature/firebase-auth`; depende de `FirebaseIdentityToolkitClient` y del manejo de `ACCOUNT_CLOSED` de esa rama).

## Global Constraints

- Ventana de reactivación: 30 días (`ones.account.reactivate-window-days`, ya existe). Enlace de fotos: **8 días**. Borrado definitivo: `closedAt + 8 días`.
- Tarea diaria a las **03:00 America/Bogota** (`cron(0 3 * * ? *)` con `ScheduleExpressionTimezone: America/Bogota`).
- Se borra todo lo que la persona posee: sus eventos con todo su contenido (incluidas fotos de invitados) y las fotos que subió en eventos ajenos. **Los invitados no reciben aviso.**
- Pagos y suscripciones **se conservan anonimizados** (sin correo, nombre, documento ni teléfono).
- Cada paso es idempotente; un fallo deja la cuenta en su estado actual y se reintenta al día siguiente. Nunca se envía el correo dos veces.
- Textos de usuario en español; comentarios de código en español como el resto del backend.
- Commits terminan con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push por SSH (`git@github.com:oscarmellizo/mvp-ones.git`).
- Comandos backend: `cd services/ones-api && JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=<Clase>`; suite completa sin `-Dtest`.

## Decisiones técnicas respecto al spec (rulings)

1. **Búsqueda de cuentas por estado:** el spec proponía un GSI `byStatus`; se usa un *scan* paginado con filtro `status IN (DISABLED, CLOSED)`. La tabla de usuarios es pequeña y la tarea corre una vez al día. Costo si es incorrecto: agregar el GSI después sin cambiar el puerto.
2. **Fotos por quien las subió:** GSI `byGuestId` en `photos` (el atributo `guestId` ya existe en todas las filas, así que DynamoDB rellena el índice solo; no hay migración de datos).
3. **Enlace de 8 días:** un enlace firmado de S3 no puede durar 8 días (máximo SigV4 7 días y las credenciales del rol ECS caducan en horas). El correo apunta a `GET {ApiPublicBaseUrl}/v1/account-exports/{userId}.{token}`; el API valida y redirige (302) a un enlace firmado de 5 minutos.
4. **Bucket propio para el ZIP:** `${StackPrefix}-${Environment}-account-exports` con regla de ciclo de vida de 9 días. No se usa el bucket de fotos porque su notificación `ObjectCreated` dispararía la lambda de miniaturas.
5. **Disparo:** EventBridge Scheduler → lambda inline → ALB (mismo patrón que la lambda de miniaturas, que ya llama `/internal` por HTTP). Las API Destinations exigen HTTPS y el listener HTTPS es opcional.
6. **Ejecución asíncrona:** el endpoint responde 202 y corre en un ejecutor de un hilo; si ya hay una corrida, responde 409. El timeout de 60 s del ALB no limita la tarea.
7. **Short links y portadas temporales:** no se borran explícitamente; los short links caducan por TTL (`expiresAt`) y apuntan a fotos ya borradas, y las portadas temporales tienen ciclo de vida de 1 día.
8. **Checkout attempts:** su clave es el correo y tienen TTL; se dejan caducar.
9. **Firebase sin configurar:** la purga falla para esa cuenta (queda `CLOSED` y se reintenta). Es coherente con el *deploy gate* de la service account.
10. **Revocación de Apple:** se hace en la app al darse de baja: reautentica con Apple, toma `additionalUserInfo.authorizationCode` y llama `FirebaseAuth.revokeTokenWithAuthorizationCode`. Requisito externo: el proveedor Apple de Firebase debe tener Services ID, Team ID, Key ID y clave privada configurados.

## Review Focus

1. **La tarea corre dos veces el mismo día (o dos corridas a la vez):** no se duplica el correo ni falla nada — test en Task 6 y Task 8.
2. **Cuenta sin fotos:** no se genera ZIP, el correo lo dice y no incluye enlace; la purga no falla por ZIP inexistente — tests en Task 4, 5, 6 y 7.
3. **Fallo a mitad de la purga (S3, DynamoDB o Firebase):** la cuenta queda `CLOSED` y la siguiente corrida termina el trabajo — test en Task 7.
4. **La persona reactiva el día 29 y la tarea corre el día 31:** su cuenta está `ACTIVE` y no se toca; una cuenta `CLOSED` ya no se puede reactivar — tests en Task 1 y Task 6.
5. **Enlace vencido, token incorrecto o cuenta ya borrada:** 404 sin revelar si la cuenta existe — test en Task 8.

---

### Task 1: Estado del ciclo de vida en el usuario

**Files:**
- Modify: `services/ones-api/src/main/java/com/ones/api/domain/users/User.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/adapters/outbound/dynamodb/DynamoUserItem.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/adapters/outbound/dynamodb/DynamoDbUsersRepository.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/application/users/ports/UsersRepository.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/application/users/AccountAccessService.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/application/users/AccountReactivateUseCase.java`
- Test: `services/ones-api/src/test/java/com/ones/api/application/users/AccountAccessServiceTest.java`, `UserUseCasesTest.java`
- Create: `services/ones-api/src/test/java/com/ones/api/application/users/InMemoryUsersRepository.java` (fake compartido)

**Interfaces:**
- Produces:
  - `User` campos nuevos `Instant closedAt`, `String exportToken`, `String exportKey`; constructor de 18 argumentos (los 15 actuales + `closedAt, exportToken, exportKey`); el de 15 delega con `null, null, null`.
  - `User withLifecycle(String status, Instant closedAt, String exportToken, String exportKey)` — copia con esos cuatro valores.
  - `User tombstone(Instant now)` — copia sin datos personales: `email, name, givenName, familyName, picture, preferredName, exportToken, exportKey = null`, `termsAccepted=false`, `status="DELETED"`, `updatedAt=now`; conserva `userId, provider, createdAt, disabledAt, closedAt`.
  - Constantes `User.STATUS_ACTIVE="ACTIVE"`, `STATUS_DISABLED="DISABLED"`, `STATUS_CLOSED="CLOSED"`, `STATUS_DELETED="DELETED"`.
  - `UsersRepository.List<User> findByStatusIn(Set<String> statuses)`.
  - `InMemoryUsersRepository implements UsersRepository` (test, público, en `com.ones.api.application.users`).

- [ ] **Step 1: Fake compartido y tests que fallan**

Mover el `InMemoryUsersRepository` privado de `AccountAccessServiceTest` a un archivo propio público y agregarle:

```java
@Override
public List<User> findByStatusIn(Set<String> statuses) {
    return store.values().stream()
            .filter(u -> u.getStatus() != null && statuses.contains(u.getStatus().toUpperCase()))
            .toList();
}
```

En `AccountAccessServiceTest` agregar:

```java
@Test
void closedStatus_isClosed_evenInsideTheWindow() {
    repo.upsert(disabledUser("u1", NOW.minus(Duration.ofDays(2))).withLifecycle("CLOSED", NOW, "t", null));
    assertEquals(AccountAccess.CLOSED, service.check("u1"));
}

@Test
void deletedTombstone_isClosed() {
    repo.upsert(disabledUser("u1", NOW.minus(Duration.ofDays(40))).tombstone(NOW));
    assertEquals(AccountAccess.CLOSED, service.check("u1"));
}
```

(`disabledUser(id, disabledAt)` es el helper existente del test; si no existe, crearlo con el constructor de 15 argumentos y `status="DISABLED"`.)

En `UserUseCasesTest` agregar:

```java
@Test
void reactivate_closedAccount_isRejected() {
    repo.upsert(disabledUser("u1", NOW.minus(Duration.ofDays(2))).withLifecycle("CLOSED", NOW, "t", null));
    assertTrue(new AccountReactivateUseCase(repo, CLOCK, Duration.ofDays(30)).execute("u1").isEmpty());
}

@Test
void tombstone_dropsPersonalData_keepsIdentity() {
    User t = disabledUser("u1", NOW.minus(Duration.ofDays(40))).withLifecycle("CLOSED", NOW, "tok", "exports/u1/x.zip").tombstone(NOW);
    assertEquals("u1", t.getUserId());
    assertEquals("DELETED", t.getStatus());
    assertNull(t.getEmail());
    assertNull(t.getPreferredName());
    assertNull(t.getExportToken());
    assertNotNull(t.getProvider());
}
```

- [ ] **Step 2: Verificar que fallan**

Run: `cd services/ones-api && JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest='AccountAccessServiceTest,UserUseCasesTest'`
Expected: error de compilación `cannot find symbol withLifecycle` / `tombstone` / `findByStatusIn`.

- [ ] **Step 3: Implementar**

`User.java`: agregar los tres campos, getters, constantes, constructor de 18 argumentos, y:

```java
public User withLifecycle(String status, Instant closedAt, String exportToken, String exportKey) {
    return new User(userId, email, name, givenName, familyName, picture, preferredName, provider,
            languagePreference, termsAccepted, createdAt, updatedAt, status, disabledAt, reactivatedAt,
            closedAt, exportToken, exportKey);
}

/** Lápida tras el borrado definitivo: sin datos personales, para que un token viejo no recree la cuenta. */
public User tombstone(Instant now) {
    return new User(userId, null, null, null, null, null, null, provider, null, false, createdAt, now,
            STATUS_DELETED, disabledAt, reactivatedAt, closedAt, null, null);
}
```

`DynamoUserItem`: atributos `closedAt`, `exportToken`, `exportKey` (String). `DynamoDbUsersRepository.toItem` los escribe solo si no son null (mismo estilo que `disabledAt`); `toDomain` los lee con el constructor de 18. `findByStatusIn`:

```java
@Override
public List<User> findByStatusIn(Set<String> statuses) {
    if (statuses == null || statuses.isEmpty()) return List.of();
    Map<String, AttributeValue> values = new HashMap<>();
    List<String> placeholders = new ArrayList<>();
    int i = 0;
    for (String s : statuses) {
        values.put(":s" + i, AttributeValue.fromS(s));
        placeholders.add(":s" + i);
        i++;
    }
    Expression filter = Expression.builder()
            .expression("#st IN (" + String.join(", ", placeholders) + ")")
            .expressionNames(Map.of("#st", "status"))
            .expressionValues(values)
            .build();
    // Scan paginado: la tabla de usuarios es pequeña y esto corre una vez al día.
    return table.scan(ScanEnhancedRequest.builder().filterExpression(filter).build())
            .items().stream().map(this::toDomain).toList();
}
```

`AccountAccessService.check`: antes de la comprobación de `DISABLED`:

```java
String status = u.getStatus() == null ? "" : u.getStatus().toUpperCase();
if (User.STATUS_CLOSED.equals(status) || User.STATUS_DELETED.equals(status)) return AccountAccess.CLOSED;
```

`AccountReactivateUseCase.execute`: si el estado es `CLOSED` o `DELETED`, devolver `Optional.empty()`.

- [ ] **Step 4: Verificar que pasan + suite**

Run: `cd services/ones-api && JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: todos pasan (81 + 4 nuevos).

- [ ] **Step 5: Commit**

```bash
git add services/ones-api/src
git commit -m "feat(api): estados CLOSED/DELETED y datos del ciclo de vida de la cuenta"
```

---

### Task 2: Puertos y adaptadores para borrar lo que posee una cuenta

**Files:**
- Modify: `application/events/ports/ObjectStorage.java`, `adapters/outbound/aws/AwsS3ObjectStorage.java`
- Modify: `application/photos/ports/PhotosRepository.java`, `adapters/outbound/dynamodb/DynamoPhotoItem.java`, `adapters/outbound/dynamodb/DynamoDbPhotosRepository.java`
- Modify: `application/photos/ports/PhotoLikesRepository.java`, `adapters/outbound/dynamodb/DynamoDbPhotoLikesRepository.java`
- Modify: `application/invitations/ports/InvitationsRepository.java`, `adapters/outbound/dynamodb/DynamoDbInvitationsRepository.java`
- Modify: `application/subscriptions/ports/SubscriptionPaymentsRepository.java`, `adapters/outbound/dynamodb/DynamoDbSubscriptionPaymentsRepository.java`
- Modify: `application/users/ports/FirebaseIdentityAdmin.java`, `adapters/outbound/firebase/FirebaseIdentityToolkitClient.java`
- Test: `src/test/java/com/ones/api/adapters/outbound/firebase/FirebaseIdentityToolkitClientTest.java`
- Modify: todos los fakes de test que implementan estos puertos (el compilador los señala).

(Rutas relativas a `services/ones-api/src/main/java/com/ones/api/`; confirmar los paquetes reales con `grep -rl "interface PhotosRepository"` etc.)

**Interfaces:**
- Produces:
  - `ObjectStorage.InputStream open(String bucket, String key)` (lanza si no existe).
  - `ObjectStorage.void putFile(String bucket, String key, Path file, String contentType)`.
  - `PhotosRepository.PageResult<Photo> listByGuestId(String guestId, int limit, String nextToken)` — índice `byGuestId`.
  - `PhotoLikesRepository.void deleteAllByUserId(String userId)` — índice `gsi1`, `gsi1pk = "user#" + userId`.
  - `InvitationsRepository.void delete(String inviteeEmail, String eventId)`.
  - `SubscriptionPaymentsRepository.List<SubscriptionPayment> listByUserId(String userId)` — índice `byUserId`.
  - `FirebaseIdentityAdmin.void deleteUser(String uid)` — idempotente (`USER_NOT_FOUND` = éxito); lanza `IllegalStateException` si no está configurado.

- [ ] **Step 1: Test que falla (Firebase)**

En `FirebaseIdentityToolkitClientTest`, con el mismo *stub exchange* que registra rutas:

```java
@Test
void deleteUser_callsAccountsDelete_andToleratesUserNotFound() {
    // stub: primera llamada responde 400 {"error":{"message":"USER_NOT_FOUND"}}
    client.deleteUser("uid-1");
    assertEquals(List.of("/v1/projects/ones-a96a7/accounts:delete"), calledPaths);
}

@Test
void deleteUser_notConfigured_throws() {
    assertThrows(IllegalStateException.class, () -> unconfiguredClient.deleteUser("uid-1"));
}
```

- [ ] **Step 2: Verificar que falla**

Run: `... -Dtest=FirebaseIdentityToolkitClientTest`
Expected: `cannot find symbol deleteUser`.

- [ ] **Step 3: Implementar**

`FirebaseIdentityToolkitClient`:

```java
@Override
public void deleteUser(String uid) {
    if (!isConfigured()) throw new IllegalStateException("Firebase admin no configurado");
    String token = accessToken();
    try {
        post("/v1/projects/" + projectId + "/accounts:delete", Map.of("localId", uid), token);
    } catch (FirebaseAdminException e) {
        if (!e.getMessage().contains("USER_NOT_FOUND")) throw e;
    }
}
```

(Usar la misma excepción y la misma tolerancia a `USER_NOT_FOUND` que ya usa `replaceWithLegacyGoogleUser` en la línea ~69; si allí la tolerancia está en un helper, reutilizarlo.)

`AwsS3ObjectStorage`:

```java
@Override
public InputStream open(String bucket, String key) {
    return client.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build());
}

@Override
public void putFile(String bucket, String key, Path file, String contentType) {
    client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType).build(),
            RequestBody.fromFile(file));
}
```

`DynamoPhotoItem.getGuestId()`: agregar `@DynamoDbSecondaryPartitionKey(indexNames = {"byGuestId"})`. `DynamoDbPhotosRepository.listByGuestId`: copiar `listByEventId` cambiando el índice a `byGuestId` y la clave a `guestId`.

`DynamoDbPhotoLikesRepository.deleteAllByUserId`: consultar `table.index("gsi1")` con `partitionValue("user#" + userId)` y borrar cada `(photoId, userId)` con el mismo manejo best-effort que `deleteAllByPhotoId`.

`DynamoDbInvitationsRepository.delete`: `table.deleteItem(Key.builder().partitionValue(inviteeEmail).sortValue(eventId).build())` (normalizar el correo igual que `findByInviteeEmailAndEventId`).

`DynamoDbSubscriptionPaymentsRepository.listByUserId`: consultar `table.index("byUserId")` con `partitionValue(userId)` y mapear con el `toDomain` existente.

Actualizar los fakes de test que implementan estos puertos (en memoria; `listByGuestId` filtra por `guestId`).

- [ ] **Step 4: Verificar**

Run: suite completa. Expected: todo pasa.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(api): puertos para borrar todo lo que posee una cuenta"
```

---

### Task 3: `EventPurger` — borrar un evento completo sin restricciones

**Files:**
- Create: `application/events/EventPurger.java`
- Modify: `application/events/DeleteEventUseCase.java` (usa `EventPurger` después de sus validaciones)
- Modify: `configuration/ApplicationConfig.java` si `DeleteEventUseCase` se construye allí (hoy es `@Service`; `EventPurger` también será `@Service`)
- Test: `src/test/java/com/ones/api/application/events/EventPurgerTest.java`

**Interfaces:**
- Consumes: `PhotosRepository.listByEventId`, `PhotoLikesRepository.deleteAllByPhotoId`, `InvitationsRepository.deleteAllByEventId`, `ObjectStorage.delete`, `EventsRepository.deleteById`.
- Produces: `EventPurger.int purge(Event event)` (devuelve fotos borradas) y `EventPurger.void purgePhoto(Photo photo)`.

- [ ] **Step 1: Test que falla**

```java
@Test
void purge_deletesGuestPhotosToo() {
    Event event = event("e1", "owner");
    photos.upsert(photo("p1", "e1", "owner"));
    photos.upsert(photo("p2", "e1", "guest"));
    events.save(event);

    int deleted = purger.purge(event);

    assertEquals(2, deleted);
    assertTrue(photos.findById("p2").isEmpty());
    assertTrue(events.findById("e1").isEmpty());
    assertTrue(storage.deleted.containsAll(List.of(
            "photos/eventos/e1/guests/guest/private/p2.jpg",
            "photos/eventos/e1/guests/guest/private/p2_m.jpg",
            "photos/eventos/e1/guests/guest/private/p2_s.jpg")));
    assertEquals(List.of("e1"), invitations.deletedEvents);
}

@Test
void purge_continuesWhenS3DeleteFails() {
    storage.failDeletes = true;
    Event event = event("e1", "owner");
    events.save(event);
    photos.upsert(photo("p1", "e1", "owner"));

    purger.purge(event);

    assertTrue(photos.findById("p1").isEmpty());
}
```

Fakes: `InMemoryPhotosRepository`, `InMemoryEventsRepository`, `RecordingObjectStorage` (registra `bucket + "/" + key` en `deleted`; `failDeletes` lanza), `RecordingInvitationsRepository`. Reutilizar los que ya existan en `src/test` (`grep -rl "implements PhotosRepository" src/test`). Bucket de fotos `"photos"`, de portadas `"covers"`.

- [ ] **Step 2: Verificar que falla**

Run: `... -Dtest=EventPurgerTest` → Expected: `cannot find symbol EventPurger`.

- [ ] **Step 3: Implementar**

Mover a `EventPurger` el bucle de borrado de fotos, `deletePhotoS3BestEffort`, `deleteS3BestEffort`, `variantKeyFromOriginal`, el borrado de portada, `deleteAllByEventId` y `deleteById` de `DeleteEventUseCase`, con la recolección de fotos paginada pero **sin** la excepción de fotos de invitados:

```java
@Service
public class EventPurger {
    // constructor: (EventsRepository, PhotosRepository, PhotoLikesRepository, InvitationsRepository, ObjectStorage,
    //               @Value("${ones.s3.events.photos.bucket}") String photosBucket,
    //               @Value("${ones.s3.events.covers.final-bucket}") String coversFinalBucket)

    public int purge(Event event) {
        List<Photo> all = new ArrayList<>();
        String next = null;
        do {
            PhotosRepository.PageResult<Photo> page = photosRepository.listByEventId(event.getEventId(), 50, next);
            all.addAll(page.items());
            next = page.nextToken();
        } while (next != null && !next.isBlank());
        all.forEach(this::purgePhoto);
        deleteCoverBestEffort(event.getCoverKey());
        invitationsRepository.deleteAllByEventId(event.getEventId());
        eventsRepository.deleteById(event.getEventId());
        return all.size();
    }

    public void purgePhoto(Photo photo) { /* S3 best-effort + likes best-effort + photosRepository.deleteById */ }
}
```

`DeleteEventUseCase.execute`: conserva validaciones y la comprobación de fotos de invitados (recorrido paginado que lanza `EventHasGuestPhotosException`), y luego llama `eventPurger.purge(event)`.

- [ ] **Step 4: Verificar**: suite completa → todo pasa (incluidos los tests existentes de borrado de eventos).

- [ ] **Step 5: Commit**: `git commit -am "refactor(api): EventPurger reutilizable para borrar eventos completos"` (+ `git add` del archivo nuevo).

---

### Task 4: `PhotosExportService` — ZIP con las fotos de la cuenta

**Files:**
- Create: `application/users/lifecycle/PhotosExportService.java`
- Test: `src/test/java/com/ones/api/application/users/lifecycle/PhotosExportServiceTest.java`

**Interfaces:**
- Consumes: `EventsRepository.listByOwnerId`, `PhotosRepository.listByEventId`, `PhotosRepository.listByGuestId`, `ObjectStorage.open`, `ObjectStorage.putFile`.
- Produces: `PhotosExportService.Optional<String> export(String userId)` — sube `exports/{userId}/ones-fotos.zip` al bucket `ones.account.exports-bucket` y devuelve la clave; `Optional.empty()` si no hay fotos.

- [ ] **Step 1: Test que falla**

```java
@Test
void export_includesOwnedEventPhotosAndOwnUploadsElsewhere_once() throws Exception {
    events.save(event("e1", "u1", "Boda Ana"));
    photos.upsert(photo("p1", "e1", "u1"));      // propia en su evento
    photos.upsert(photo("p2", "e1", "guest"));   // de un invitado en su evento
    photos.upsert(photo("p3", "e9", "u1"));      // subida en evento ajeno
    storage.objects.put("photos/" + photo("p1","e1","u1").getS3KeyOriginal(), "a".getBytes());
    storage.objects.put("photos/" + photo("p2","e1","guest").getS3KeyOriginal(), "b".getBytes());
    storage.objects.put("photos/" + photo("p3","e9","u1").getS3KeyOriginal(), "c".getBytes());

    Optional<String> key = service.export("u1");

    assertEquals(Optional.of("exports/u1/ones-fotos.zip"), key);
    assertEquals(Set.of("p1.jpg", "p2.jpg", "p3.jpg"), zipEntryFileNames(storage.uploaded.get("exports/exports/u1/ones-fotos.zip")));
}

@Test
void export_noPhotos_returnsEmpty_andUploadsNothing() {
    assertTrue(service.export("u1").isEmpty());
    assertTrue(storage.uploaded.isEmpty());
}

@Test
void export_skipsMissingObjects() {
    photos.upsert(photo("p1", "e9", "u1")); // sin objeto en S3
    events.save(event("e9", "other", "Otro"));
    assertTrue(service.export("u1").isEmpty());
}
```

`storage.uploaded` guarda una copia en memoria de los bytes del archivo subido (`bucket + "/" + key`). Bucket de exportaciones en el test: `"exports"`. `zipEntryFileNames` lee el ZIP con `ZipInputStream` y devuelve el nombre de archivo final de cada entrada.

- [ ] **Step 2: Verificar que falla** → `cannot find symbol PhotosExportService`.

- [ ] **Step 3: Implementar**

```java
@Service
public class PhotosExportService {
    // constructor: (EventsRepository, PhotosRepository, ObjectStorage,
    //   @Value("${ones.s3.events.photos.bucket}") String photosBucket,
    //   @Value("${ones.account.exports-bucket:}") String exportsBucket)

    public Optional<String> export(String userId) {
        Map<String, Photo> byId = new LinkedHashMap<>();
        for (Event e : eventsRepository.listByOwnerId(userId, 200)) {
            collect(byId, next -> photosRepository.listByEventId(e.getEventId(), 100, next));
        }
        collect(byId, next -> photosRepository.listByGuestId(userId, 100, next));

        Path tmp = Files.createTempFile("ones-export-", ".zip");
        try {
            int written = 0;
            // Se escribe a disco (no a memoria): una cuenta puede tener miles de fotos.
            try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(tmp))) {
                for (Photo p : byId.values()) {
                    try (InputStream in = objectStorage.open(photosBucket, p.getS3KeyOriginal())) {
                        zip.putNextEntry(new ZipEntry(p.getEventId() + "/" + p.getPhotoId() + ".jpg"));
                        in.transferTo(zip);
                        zip.closeEntry();
                        written++;
                    } catch (Exception ex) {
                        log.warn("[PhotosExportService] foto omitida photoId={} err={}", p.getPhotoId(), ex.toString());
                    }
                }
            }
            if (written == 0) return Optional.empty();
            String key = "exports/" + userId + "/ones-fotos.zip";
            objectStorage.putFile(exportsBucket, key, tmp, "application/zip");
            return Optional.of(key);
        } finally {
            Files.deleteIfExists(tmp);
        }
    }
}
```

(Envolver `IOException` en `UncheckedIOException`. `collect` pagina hasta `nextToken` vacío y hace `putIfAbsent(photoId, photo)`. Si `listByOwnerId` está limitado a 200, documentarlo con un comentario: una cuenta con más de 200 eventos no existe hoy.)

`application.yml`: `ones.account.exports-bucket: ${ONES_ACCOUNT_EXPORTS_BUCKET:}`.

- [ ] **Step 4: Verificar**: `-Dtest=PhotosExportServiceTest` pasa; suite completa pasa.

- [ ] **Step 5: Commit**: `feat(api): exportación de fotos de la cuenta en ZIP`.

---

### Task 5: Correo con el enlace de las fotos

**Files:**
- Modify: `application/users/email/AccountEmailService.java`
- Create: `src/test/java/com/ones/api/application/users/email/AccountEmailServiceTest.java`

**Interfaces:**
- Produces: `boolean AccountEmailService.sendClosureEmail(User user, String downloadUrl, Instant linkExpiresAt)` — `downloadUrl` null = sin fotos. Devuelve `true` si SES aceptó el correo o si el correo está deshabilitado (`enabled=false`, para entornos locales); `false` si SES falló.

- [ ] **Step 1: Test que falla**

```java
@Test
void closureEmail_withPhotos_includesLinkAndExpiry() {
    SesV2Client ses = mock(SesV2Client.class);
    var svc = new AccountEmailService(ses, new SimpleMeterRegistry(), "donotreply@ones.events",
            "https://ones.events", "", true);

    assertTrue(svc.sendClosureEmail(user("ana@example.com"), "https://api.ones.events/v1/account-exports/u1.tok",
            Instant.parse("2026-10-10T08:00:00Z")));

    ArgumentCaptor<SendEmailRequest> req = ArgumentCaptor.forClass(SendEmailRequest.class);
    verify(ses).sendEmail(req.capture());
    String text = req.getValue().content().simple().body().text().data();
    assertTrue(text.contains("https://api.ones.events/v1/account-exports/u1.tok"));
    assertTrue(text.contains("2026-10-10"));
    assertTrue(text.contains("8 días"));
}

@Test
void closureEmail_withoutPhotos_saysSo_andHasNoLink() {
    // mismo setup; downloadUrl = null
    // assert text contiene "no tenía fotos" y no contiene "account-exports"
}

@Test
void closureEmail_sesFails_returnsFalse() {
    // when(ses.sendEmail(any(SendEmailRequest.class))).thenThrow(SesV2Exception.builder().message("x").build());
    // assertFalse(...)
}
```

- [ ] **Step 2: Verificar que falla** → `cannot find symbol sendClosureEmail`.

- [ ] **Step 3: Implementar**

Mismo armado de `SendEmailRequest` que `sendDeactivationEmail` (extraer un helper privado `boolean send(String to, String subject, String html, String text, String metric)` y que `sendDeactivationEmail` lo use). Asunto: `"Tu cuenta de Ones fue cerrada"`. Texto con fotos:

> Hola {preferredName o "hola"}: pasaron 30 días desde que desactivaste tu cuenta, así que la cerramos. Puedes descargar tus fotos aquí: {downloadUrl}. El enlace dura 8 días (hasta el {fecha}). Después borraremos tu cuenta y todo su contenido definitivamente.

Texto sin fotos:

> Hola: pasaron 30 días desde que desactivaste tu cuenta, así que la cerramos. Tu cuenta no tenía fotos para descargar. En 8 días borraremos tu cuenta y todo su contenido definitivamente.

HTML con el mismo contenido, botón "Descargar mis fotos" cuando hay enlace, logo y `data-ones-template="account-closure-v1"`. Métricas `ones.email.account_closure.sent` / `.failed`.

- [ ] **Step 4: Verificar**: test y suite pasan.

- [ ] **Step 5: Commit**: `feat(api): correo de cierre de cuenta con enlace de fotos`.

---

### Task 6: `CloseExpiredAccountsUseCase`

**Files:**
- Create: `application/users/lifecycle/CloseExpiredAccountsUseCase.java`
- Test: `src/test/java/com/ones/api/application/users/lifecycle/CloseExpiredAccountsUseCaseTest.java`
- Modify: `configuration/ApplicationConfig.java` (bean)

**Interfaces:**
- Consumes: `UsersRepository.findByStatusIn`, `User.withLifecycle`, `PhotosExportService.export`, `AccountEmailService.sendClosureEmail`, `AccountAccessService.evict`.
- Produces: `CloseExpiredAccountsUseCase.int execute()` (cuentas cerradas). Constructor `(UsersRepository, PhotosExportService, AccountEmailService, AccountAccessService, Clock, Duration window, String apiPublicBaseUrl)`. `static Duration LINK_TTL = Duration.ofDays(8)`.

- [ ] **Step 1: Tests que fallan**

```java
private static final Instant NOW = Instant.parse("2026-10-02T08:00:00Z");

@Test
void day29_isNotClosed() {
    repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(29))));
    assertEquals(0, useCase.execute());
    assertEquals("DISABLED", repo.findById("u1").get().getStatus());
    verifyNoInteractions(email);
}

@Test
void day30_closes_exportsAndEmailsOnce() {
    repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(30)).minusSeconds(1)));
    when(exporter.export("u1")).thenReturn(Optional.of("exports/u1/ones-fotos.zip"));
    when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

    assertEquals(1, useCase.execute());
    assertEquals(0, useCase.execute()); // segunda corrida: ya está CLOSED

    User u = repo.findById("u1").get();
    assertEquals("CLOSED", u.getStatus());
    assertEquals(NOW, u.getClosedAt());
    assertEquals("exports/u1/ones-fotos.zip", u.getExportKey());
    assertTrue(u.getExportToken().length() >= 32);
    verify(email, times(1)).sendClosureEmail(any(),
            eq("https://api.ones.events/v1/account-exports/u1." + u.getExportToken()),
            eq(NOW.plus(Duration.ofDays(8))));
    verify(access).evict("u1");
}

@Test
void noPhotos_closesWithoutLink() {
    repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
    when(exporter.export("u1")).thenReturn(Optional.empty());
    when(email.sendClosureEmail(any(), isNull(), any())).thenReturn(true);
    assertEquals(1, useCase.execute());
    assertNull(repo.findById("u1").get().getExportKey());
}

@Test
void emailFails_staysDisabled_forRetry() {
    repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
    when(exporter.export("u1")).thenReturn(Optional.empty());
    when(email.sendClosureEmail(any(), any(), any())).thenReturn(false);
    assertEquals(0, useCase.execute());
    assertEquals("DISABLED", repo.findById("u1").get().getStatus());
}

@Test
void exportFails_otherAccountsStillProcessed() {
    repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
    repo.upsert(disabled("u2", NOW.minus(Duration.ofDays(31))));
    when(exporter.export("u1")).thenThrow(new RuntimeException("s3"));
    when(exporter.export("u2")).thenReturn(Optional.empty());
    when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);
    assertEquals(1, useCase.execute());
    assertEquals("DISABLED", repo.findById("u1").get().getStatus());
}

@Test
void reactivatedAccount_isIgnored() {
    repo.upsert(active("u1"));
    assertEquals(0, useCase.execute());
}
```

`exporter`, `email`, `access` son mocks de Mockito; `repo` es `InMemoryUsersRepository`. `disabled(id, at)` construye un `User` con `status="DISABLED"` y `disabledAt=at`.

- [ ] **Step 2: Verificar que falla** → `cannot find symbol CloseExpiredAccountsUseCase`.

- [ ] **Step 3: Implementar**

```java
public int execute() {
    Instant now = Instant.now(clock);
    int closed = 0;
    for (User u : usersRepository.findByStatusIn(Set.of(User.STATUS_DISABLED))) {
        if (u.getDisabledAt() == null || !now.isAfter(u.getDisabledAt().plus(window))) continue;
        try {
            Optional<String> exportKey = photosExportService.export(u.getUserId());
            String token = randomToken(); // 32 bytes SecureRandom, Base64 URL sin relleno
            String url = exportKey.map(k -> base + "/v1/account-exports/" + u.getUserId() + "." + token).orElse(null);
            Instant linkExpiresAt = now.plus(LINK_TTL);
            // El correo va antes de persistir CLOSED: si falla, la próxima corrida lo reintenta.
            if (!accountEmailService.sendClosureEmail(u, url, linkExpiresAt)) continue;
            usersRepository.upsert(u.withLifecycle(User.STATUS_CLOSED, now, token, exportKey.orElse(null)));
            accountAccessService.evict(u.getUserId());
            closed++;
        } catch (Exception e) {
            log.warn("[CloseExpiredAccounts] userId={} err={}", u.getUserId(), e.toString());
        }
    }
    return closed;
}
```

(`base` = `apiPublicBaseUrl` sin `/` final.) Bean en `ApplicationConfig` leyendo `ones.account.reactivate-window-days` y `ones.api.public-base-url` (`application.yml`: `ones.api.public-base-url: ${ONES_API_PUBLIC_BASE_URL:}`).

- [ ] **Step 4: Verificar**: test y suite pasan.

- [ ] **Step 5: Commit**: `feat(api): cierre de cuentas con más de 30 días de baja`.

---

### Task 7: `PurgeClosedAccountsUseCase`

**Files:**
- Create: `application/users/lifecycle/PurgeClosedAccountsUseCase.java`
- Test: `src/test/java/com/ones/api/application/users/lifecycle/PurgeClosedAccountsUseCaseTest.java`
- Modify: `configuration/ApplicationConfig.java`

**Interfaces:**
- Consumes: `EventPurger.purge/purgePhoto`, `EventsRepository.listByOwnerId`, `PhotosRepository.listByGuestId`, `PhotoLikesRepository.deleteAllByUserId`, `InvitationsRepository.listByInviteeEmail/delete`, `PaymentProfilesRepository.findByUserId/upsert`, `SubscriptionPaymentsRepository.listByUserId/upsert`, `PreferredNamesCacheRepository.delete`, `ObjectStorage.delete`, `FirebaseIdentityAdmin.deleteUser`, `User.tombstone`.
- Produces: `PurgeClosedAccountsUseCase.int execute()` (cuentas borradas). `static Duration GRACE = Duration.ofDays(8)`.

- [ ] **Step 1: Tests que fallan**

```java
@Test
void day7AfterClosure_isNotPurged() {
    repo.upsert(closed("u1", NOW.minus(Duration.ofDays(7))));
    assertEquals(0, useCase.execute());
    verifyNoInteractions(firebase);
}

@Test
void day8_purgesEverything_andLeavesTombstone() {
    repo.upsert(closed("u1", NOW.minus(Duration.ofDays(8)).minusSeconds(1)));  // email ana@example.com, exportKey "exports/u1/ones-fotos.zip"
    events.save(event("e1", "u1"));
    photos.upsert(photo("p9", "e9", "u1"));            // foto en evento ajeno
    invitations.upsert(invitation("ana@example.com", "e9"));
    profiles.upsert(profile("u1", "ana@mp.com", "123", "3001234567", "Ana Pérez"));
    payments.upsert(payment("pay1", "u1", "ana@mp.com"));

    assertEquals(1, useCase.execute());

    verify(purger).purge(argThat(e -> e.getEventId().equals("e1")));
    verify(purger).purgePhoto(argThat(p -> p.getPhotoId().equals("p9")));
    verify(likes).deleteAllByUserId("u1");
    assertTrue(invitations.listByInviteeEmail("ana@example.com", 10).isEmpty());
    assertTrue(storage.deleted.contains("exports/exports/u1/ones-fotos.zip"));
    PaymentProfile p = profiles.findByUserId("u1").get();
    assertNull(p.getMercadoPagoEmail()); assertNull(p.getDocumentNumber());
    assertNull(p.getPhoneNumber()); assertNull(p.getFullName());
    assertNull(payments.findByPaymentId("pay1").get().getPayerEmail());
    verify(names).delete("u1");
    verify(firebase).deleteUser("u1");
    User t = repo.findById("u1").get();
    assertEquals("DELETED", t.getStatus());
    assertNull(t.getEmail());
}

@Test
void firebaseFails_staysClosed_andNextRunFinishes() {
    repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
    doThrow(new IllegalStateException("no configurado")).doNothing().when(firebase).deleteUser("u1");

    assertEquals(0, useCase.execute());
    assertEquals("CLOSED", repo.findById("u1").get().getStatus());

    assertEquals(1, useCase.execute());
    assertEquals("DELETED", repo.findById("u1").get().getStatus());
}

@Test
void alreadyDeleted_isIgnored() {
    repo.upsert(closed("u1", NOW.minus(Duration.ofDays(20))).tombstone(NOW));
    assertEquals(0, useCase.execute());
}
```

`purger`, `likes`, `names`, `firebase` son mocks; `events`, `photos`, `invitations`, `profiles`, `payments`, `storage` son fakes en memoria (reutilizar los de Task 3; crear `InMemoryPaymentProfilesRepository`, `InMemorySubscriptionPaymentsRepository` en el paquete del test si no existen). `closed(id, closedAt)` = usuario `DISABLED` hace 40 días con `withLifecycle("CLOSED", closedAt, "tok", "exports/u1/ones-fotos.zip")` y correo `ana@example.com`.

- [ ] **Step 2: Verificar que falla** → `cannot find symbol PurgeClosedAccountsUseCase`.

- [ ] **Step 3: Implementar**

```java
public int execute() {
    Instant now = Instant.now(clock);
    int purged = 0;
    for (User u : usersRepository.findByStatusIn(Set.of(User.STATUS_CLOSED))) {
        if (u.getClosedAt() == null || !now.isAfter(u.getClosedAt().plus(GRACE))) continue;
        try {
            purge(u);
            usersRepository.upsert(u.tombstone(now));
            accountAccessService.evict(u.getUserId());
            purged++;
        } catch (Exception e) {
            // Todo lo anterior es idempotente: mañana se retoma desde el principio.
            log.warn("[PurgeClosedAccounts] userId={} err={}", u.getUserId(), e.toString());
        }
    }
    return purged;
}

private void purge(User u) {
    String userId = u.getUserId();
    for (Event e : eventsRepository.listByOwnerId(userId, 200)) eventPurger.purge(e);
    String next = null;
    do {
        PhotosRepository.PageResult<Photo> page = photosRepository.listByGuestId(userId, 50, next);
        page.items().forEach(eventPurger::purgePhoto);
        next = page.nextToken();
    } while (next != null && !next.isBlank());
    photoLikesRepository.deleteAllByUserId(userId);
    if (u.getEmail() != null) {
        for (Invitation inv : invitationsRepository.listByInviteeEmail(u.getEmail(), 500)) {
            invitationsRepository.delete(inv.getInviteeEmail(), inv.getEventId());
        }
    }
    if (u.getExportKey() != null) objectStorage.delete(exportsBucket, u.getExportKey());
    paymentProfilesRepository.findByUserId(userId).ifPresent(p -> paymentProfilesRepository.upsert(
            new PaymentProfile(p.getUserId(), null, p.getCountry(), p.getDocumentType(), null, null, null,
                    p.getCreatedAt(), Instant.now(clock), p.getVerifiedAt())));
    for (SubscriptionPayment sp : subscriptionPaymentsRepository.listByUserId(userId)) {
        subscriptionPaymentsRepository.upsert(sp.withoutPayerEmail()); // agregar este método al dominio
    }
    preferredNamesCacheRepository.delete(userId);
    firebaseIdentityAdmin.deleteUser(userId); // último: si falla, la cuenta sigue CLOSED y se reintenta
}
```

`SubscriptionPayment.withoutPayerEmail()`: copia con `payerEmail=null` (los demás 13 campos iguales). Bean en `ApplicationConfig`.

- [ ] **Step 4: Verificar**: test y suite pasan.

- [ ] **Step 5: Commit**: `feat(api): borrado definitivo de cuentas cerradas`.

---

### Task 8: Endpoints — disparo interno y descarga del ZIP

**Files:**
- Create: `application/users/lifecycle/AccountLifecycleJob.java`
- Create: `adapters/inbound/rest/internal/InternalAccountsController.java`
- Create: `adapters/inbound/rest/users/AccountExportsController.java`
- Modify: `configuration/SecurityConfig.java` (permitir `GET /v1/account-exports/*` sin autenticación)
- Test: `src/test/java/com/ones/api/application/users/lifecycle/AccountLifecycleJobTest.java`, `src/test/java/com/ones/api/adapters/inbound/rest/users/AccountExportsControllerTest.java`

**Interfaces:**
- Consumes: `CloseExpiredAccountsUseCase.execute`, `PurgeClosedAccountsUseCase.execute`, `UsersRepository.findById`, `ObjectStoragePresigner.presignGet(bucket, key, Duration)`.
- Produces:
  - `AccountLifecycleJob.boolean start()` — `false` si ya hay una corrida; `record Result(int closed, int purged)` registrado en log.
  - `POST /internal/accounts/lifecycle` → 202 `{"started":true}` o 409 `{"code":"RUN_IN_PROGRESS"}`.
  - `GET /v1/account-exports/{userId}.{token}` → 302 a un enlace firmado de 5 minutos, o 404.

- [ ] **Step 1: Tests que fallan**

```java
// AccountLifecycleJobTest
@Test
void start_runsCloseThenPurge_once_whileRunning() throws Exception {
    CountDownLatch release = new CountDownLatch(1);
    when(close.execute()).thenAnswer(i -> { release.await(); return 1; });
    when(purge.execute()).thenReturn(2);
    AccountLifecycleJob job = new AccountLifecycleJob(close, purge, Executors.newSingleThreadExecutor());

    assertTrue(job.start());
    assertFalse(job.start());   // corrida en curso
    release.countDown();
    job.awaitIdle(Duration.ofSeconds(5)); // helper de test, package-private

    InOrder order = inOrder(close, purge);
    order.verify(close).execute();
    order.verify(purge).execute();
    assertTrue(job.start());    // terminó: se puede volver a lanzar
}

@Test
void closeFailure_stillRunsPurge() { /* close lanza RuntimeException → purge igual se llama */ }

// AccountExportsControllerTest (controlador instanciado directamente)
@Test
void validToken_redirectsToShortLivedLink() {
    repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(1))));
    when(presigner.presignGet("exports", "exports/u1/ones-fotos.zip", Duration.ofMinutes(5)))
            .thenReturn(new URL("https://s3.example/x"));
    ResponseEntity<Void> r = controller.download("u1.tok123");
    assertEquals(302, r.getStatusCode().value());
    assertEquals("https://s3.example/x", r.getHeaders().getLocation().toString());
}

@Test void wrongToken_404() { /* "u1.otro" → 404 */ }
@Test void after8Days_404() { /* closedAt = NOW - 8 días - 1 s → 404 */ }
@Test void deletedAccount_404() { /* lápida → 404 */ }
@Test void malformed_404() { /* "sinpunto" → 404 */ }
```

- [ ] **Step 2: Verificar que fallan** → clases inexistentes.

- [ ] **Step 3: Implementar**

`AccountLifecycleJob` (`@Component`): `AtomicBoolean running`; `start()` hace `compareAndSet(false, true)`, envía al ejecutor una tarea que ejecuta `close.execute()` y `purge.execute()` en `try/catch` separados, registra `[AccountLifecycle] closed={} purged={}` y en `finally` pone `running=false`. El ejecutor de producción es un `Executors.newSingleThreadExecutor()` creado en el constructor `@Autowired`; el constructor de test lo recibe.

`InternalAccountsController` (`@RestController @RequestMapping("/internal/accounts")`), igual a `InternalPhotosController`:

```java
@PostMapping("/lifecycle")
public ResponseEntity<Map<String, Object>> lifecycle() {
    return job.start()
            ? ResponseEntity.accepted().body(Map.of("started", true))
            : ResponseEntity.status(409).body(Map.of("code", "RUN_IN_PROGRESS"));
}
```

`AccountExportsController` (`@RestController @RequestMapping("/v1/account-exports")`):

```java
@GetMapping("/{ref}")
public ResponseEntity<Void> download(@PathVariable String ref) {
    int dot = ref.indexOf('.');
    if (dot <= 0) return ResponseEntity.notFound().build();
    String userId = ref.substring(0, dot), token = ref.substring(dot + 1);
    Optional<User> user = usersRepository.findById(userId);
    Instant now = Instant.now(clock);
    boolean ok = user.isPresent()
            && User.STATUS_CLOSED.equals(user.get().getStatus())
            && user.get().getExportKey() != null
            && user.get().getExportToken() != null
            && MessageDigest.isEqual(user.get().getExportToken().getBytes(UTF_8), token.getBytes(UTF_8))
            && now.isBefore(user.get().getClosedAt().plus(CloseExpiredAccountsUseCase.LINK_TTL));
    if (!ok) return ResponseEntity.notFound().build();
    URL url = presigner.presignGet(exportsBucket, user.get().getExportKey(), Duration.ofMinutes(5));
    return ResponseEntity.status(HttpStatus.FOUND).location(URI.create(url.toString())).build();
}
```

`SecurityConfig`, en la cadena principal (`@Order(4)`), junto a los demás `permitAll`: `.requestMatchers(HttpMethod.GET, "/v1/account-exports/*").permitAll()`. Verificar que `DisabledAccountFilter` no interfiere (solo actúa con `JwtAuthenticationToken`).

- [ ] **Step 4: Verificar**: tests nuevos y suite completa pasan.

- [ ] **Step 5: Commit**: `feat(api): disparo interno de la tarea diaria y descarga del ZIP`.

---

### Task 9: Infraestructura

**Files:**
- Modify: `infra/cloudformation/backend/all.yml`, `infra/cloudformation/backend/root.yml`
- Modify: `.github/workflows/deploy-infra-backend.yml`

**Interfaces:**
- Consumes: variables `ONES_ACCOUNT_EXPORTS_BUCKET`, `ONES_API_PUBLIC_BASE_URL`, `ONES_INTERNAL_BASIC_USERNAME`, `ONES_INTERNAL_BASIC_PASSWORD` (Tasks 4, 6, 8 y `SecurityConfig`).

- [ ] **Step 1: Cambios en `all.yml`**

1. Parámetro `ApiPublicBaseUrl` (`Type: String`, `Default: ''`); pasarlo desde `root.yml` como los demás.
2. Bucket:

```yaml
  AccountExportsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub ${StackPrefix}-${Environment}-account-exports
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      LifecycleConfiguration:
        Rules:
          - Id: ExpireExports
            Status: Enabled
            ExpirationInDays: 9
```

3. GSI `byGuestId` en la tabla de fotos (agregar `guestId` a `AttributeDefinitions`):

```yaml
        - IndexName: byGuestId
          KeySchema:
            - AttributeName: guestId
              KeyType: HASH
          Projection:
            ProjectionType: ALL
          ProvisionedThroughput:
            ReadCapacityUnits: 5
            WriteCapacityUnits: 2
```

4. `TaskRole` → política `ones-s3`: agregar `!Sub ${AccountExportsBucket.Arn}/*` a los recursos.
5. `TaskDefinition` del backend → `Environment`: `ONES_ACCOUNT_EXPORTS_BUCKET: !Ref AccountExportsBucket`, `ONES_API_PUBLIC_BASE_URL: !Ref ApiPublicBaseUrl`. `Secrets`: `ONES_INTERNAL_BASIC_USERNAME` ← `!Sub '${InternalBasicAuthSecret}:username::'`, `ONES_INTERNAL_BASIC_PASSWORD` ← `!Sub '${InternalBasicAuthSecret}:password::'` (mismo patrón que `ONES_ACTUATOR_BASIC_*`).
6. Lambda de disparo + rol + programación:

```yaml
  AccountLifecycleTriggerRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: { Service: lambda.amazonaws.com }
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: read-internal-secret
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: secretsmanager:GetSecretValue
                Resource: !Ref InternalBasicAuthSecret

  AccountLifecycleTriggerFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub ${StackPrefix}-${Environment}-account-lifecycle-trigger
      Runtime: python3.12
      Handler: index.handler
      Timeout: 30
      Role: !GetAtt AccountLifecycleTriggerRole.Arn
      Environment:
        Variables:
          BACKEND_BASE_URL: !Sub http://${LoadBalancer.DNSName}
          INTERNAL_SECRET_ARN: !Ref InternalBasicAuthSecret
      Code:
        ZipFile: |
          import base64, json, os, urllib.request, urllib.error
          import boto3

          def handler(event, context):
              secret = json.loads(boto3.client('secretsmanager').get_secret_value(
                  SecretId=os.environ['INTERNAL_SECRET_ARN'])['SecretString'])
              auth = base64.b64encode(f"{secret['username']}:{secret['password']}".encode()).decode()
              req = urllib.request.Request(
                  os.environ['BACKEND_BASE_URL'] + '/internal/accounts/lifecycle',
                  data=b'{}', method='POST',
                  headers={'Authorization': 'Basic ' + auth, 'Content-Type': 'application/json'})
              try:
                  with urllib.request.urlopen(req, timeout=20) as r:
                      print('lifecycle', r.status, r.read().decode())
              except urllib.error.HTTPError as e:
                  if e.code == 409:
                      print('lifecycle ya en curso')
                      return
                  raise

  AccountLifecycleSchedulerRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: { Service: scheduler.amazonaws.com }
            Action: sts:AssumeRole
      Policies:
        - PolicyName: invoke-trigger
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: lambda:InvokeFunction
                Resource: !GetAtt AccountLifecycleTriggerFunction.Arn

  AccountLifecycleSchedule:
    Type: AWS::Scheduler::Schedule
    Properties:
      Name: !Sub ${StackPrefix}-${Environment}-account-lifecycle
      ScheduleExpression: cron(0 3 * * ? *)
      ScheduleExpressionTimezone: America/Bogota
      FlexibleTimeWindow: { Mode: 'OFF' }
      Target:
        Arn: !GetAtt AccountLifecycleTriggerFunction.Arn
        RoleArn: !GetAtt AccountLifecycleSchedulerRole.Arn
        RetryPolicy:
          MaximumRetryAttempts: 2
```

- [ ] **Step 2: Workflow**

En `.github/workflows/deploy-infra-backend.yml`, junto a `FirebaseProjectId`, pasar `ApiPublicBaseUrl=https://apidev.ones.events` para dev y `https://api.ones.events` para prod (mismo `if` por ambiente que usa `deploy-infra-web.yml` para `albDns`).

- [ ] **Step 3: Validar**

Run: `cfn-lint infra/cloudformation/backend/all.yml infra/cloudformation/backend/root.yml` (si no está instalado: `pipx run cfn-lint ...`).
Expected: sin errores nuevos (comparar con `git stash; cfn-lint ...; git stash pop` si hay advertencias previas).

- [ ] **Step 4: Commit**: `feat(infra): bucket de exportaciones, índice byGuestId y tarea diaria de cuentas` (push por SSH porque toca `.github/workflows`).

---

### Task 10: App — texto de baja y revocación de Apple

**Files:**
- Modify: `apps/ones_app/lib/features/account/presentation/pages/account_page.dart` (líneas ~51 y ~70-72)
- Modify: `apps/ones_app/lib/features/auth/domain/auth_repository.dart`, `apps/ones_app/lib/features/auth/adapters/firebase/firebase_auth_repository.dart`
- Modify: `apps/ones_app/lib/features/account/presentation/account_controller.dart` (`deactivateAndSignOut`)
- Test: `apps/ones_app/test/features/account/...` (test existente del controlador de cuenta; si no existe, crear `account_controller_test.dart`) y el fake de `AuthRepository` en `test/`.

**Interfaces:**
- Produces: `AuthRepository.Future<void> revokeAppleAccessIfNeeded()` — en usuarios `apple.com` reautentica con Apple, toma `additionalUserInfo?.authorizationCode` y llama `FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code)`; en otros proveedores no hace nada. Cancelación del usuario → `AuthException(AuthFailure.cancelled)`.

- [ ] **Step 1: Tests que fallan**

```dart
test('baja con Apple revoca el acceso antes de desactivar', () async {
  repo.current = fakeUser(provider: 'apple.com');
  await controller.deactivateAndSignOut(auth);
  expect(repo.calls, ['revokeAppleAccessIfNeeded', 'deactivate', 'signOut']);
});

test('si cancela el diálogo de Apple no se desactiva la cuenta', () async {
  repo.current = fakeUser(provider: 'apple.com');
  repo.revokeError = const AuthException(AuthFailure.cancelled);
  await controller.deactivateAndSignOut(auth);
  expect(repo.calls, ['revokeAppleAccessIfNeeded']);
});

testWidgets('el texto de baja menciona el enlace de 8 días', (tester) async {
  await pumpAccountPage(tester);
  expect(find.textContaining('el enlace dura 8 días'), findsOneWidget);
});
```

(Ajustar `repo.calls` al fake existente: registrar el nombre de cada método llamado; `deactivate` lo registra el fake de la API de cuenta.)

- [ ] **Step 2: Verificar que fallan**: `cd apps/ones_app && flutter test test/features/account`.

- [ ] **Step 3: Implementar**

Texto (tarjeta y primer diálogo):

> Tu cuenta se desactivará ahora. Si vuelves a iniciar sesión dentro de los próximos 30 días, se reactivará automáticamente. Pasados 30 días te enviaremos tus fotos por correo; el enlace dura 8 días y después borraremos tu cuenta y todo su contenido definitivamente.

`FirebaseAuthRepository.revokeAppleAccessIfNeeded`:

```dart
@override
Future<void> revokeAppleAccessIfNeeded() => _guard(() async {
  final user = _auth.currentUser;
  if (user == null || !user.providerData.any((p) => p.providerId == 'apple.com')) return;
  final cred = await user.reauthenticateWithProvider(AppleAuthProvider());
  final code = cred.additionalUserInfo?.authorizationCode;
  if (code == null) return; // sin código no se puede revocar; la baja sigue
  await _auth.revokeTokenWithAuthorizationCode(code);
});
```

`AccountController.deactivateAndSignOut`: llamar `revokeAppleAccessIfNeeded()` primero; si lanza `cancelled`, salir sin desactivar; otros errores se registran y la baja continúa.

- [ ] **Step 4: Verificar**: `flutter test` completo (solo debe fallar `list_events_use_case_test`, preexistente) y `flutter analyze lib` sin errores nuevos.

- [ ] **Step 5: Commit**: `feat(app): texto de baja con enlace de 8 días y revocación de Apple`.

---

### Task 11: Verificación local de punta a punta

**Files:** ninguno (solo verificación; scripts en el scratchpad).

- [ ] **Step 1:** Levantar DynamoDB local (`docker start ones-dynamodb-local`), recrear la tabla de fotos con el GSI `byGuestId` desde `all.yml` y arrancar el backend con `ONES_INTERNAL_BASIC_USERNAME/PASSWORD` de prueba, `ONES_EMAIL_ENABLED=false`, `ONES_API_PUBLIC_BASE_URL=http://localhost:8090/api` y el resto de variables del entorno local habitual.
- [ ] **Step 2:** Sembrar en local: una cuenta `DISABLED` hace 31 días y otra `CLOSED` hace 9 días con un evento propio y una invitación.
- [ ] **Step 3:** `curl -u user:pass -X POST http://localhost:8090/api/internal/accounts/lifecycle` → Expected: `202 {"started":true}`; una segunda llamada inmediata → `409` o `202` si ya terminó.
- [ ] **Step 4:** Leer la base: la primera cuenta queda `CLOSED` con `exportToken`; la segunda queda `DELETED` sin correo y su evento e invitación ya no existen. La exportación a S3 y Firebase fallarán sin credenciales reales: confirmar en el log que la cuenta afectada **queda en su estado** (comportamiento esperado de reintento) y no se marca como procesada.
- [ ] **Step 5:** `curl -i http://localhost:8090/api/v1/account-exports/u1.malo` → `404`.

---

## Prerrequisitos externos (la persona dueña del proyecto)

1. `InternalBasicAuthSecret` con usuario y contraseña reales en cada ambiente (hoy se crea vacío; la lambda de miniaturas ya depende de él).
2. Proveedor Apple de Firebase con Services ID, Team ID, Key ID y clave privada (para `revokeTokenWithAuthorizationCode`).
3. Service account de Firebase cargada (ya es requisito de `feature/firebase-auth`).
4. SES fuera de sandbox en prod para enviar a cualquier correo.
