# Database Migrations

This document describes how to run database migrations for the Ones API backend.

## Translations Migration

The translations migration script populates the `TranslationsTable` in DynamoDB with initial translations for Spanish, English, and Portuguese.

### How to Run

1. **Build the application**:
   ```bash
   cd services/ones-api
   mvn clean package
   ```

2. **Run the migration with the `migrate-translations` profile**:
   ```bash
   java -jar target/ones-api-*.jar --spring.profiles.active=migrate-translations
   ```

   Or using Maven:
   ```bash
   mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
   ```

### What It Does

The migration:
- Reads the `initial-translations.json` file from `src/main/resources/`
- Inserts all translations into the DynamoDB `TranslationsTable`
- Uses the `TranslationsRepository` to upsert each translation
- Logs each translation as it is migrated
- Reports the total number of translations migrated at the end

### Translation Keys

The initial translations include keys for:
- **Profile page**: account info, preferences, language selector, error messages
- **Admin pages**: frames, event templates, translations, administrators
- **Common elements**: cancel, delete, save, edit, add, back, loading, error, success

### After Migration

After running the migration:
1. Verify the translations in DynamoDB using the AWS Console or the Admin Translations UI
2. The translations will be available for the Flutter app to load
3. You can edit translations through the Admin Translations UI in the Flutter app

### Re-running the Migration

The migration can be safely re-run multiple times. It uses `upsert` operations, so existing translations will be updated with the values from the JSON file. This is useful for:
- Adding new translation keys
- Updating existing translation values
- Ensuring consistency across environments
