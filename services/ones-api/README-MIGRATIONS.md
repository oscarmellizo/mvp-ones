# Database Migrations

This document describes how to run database migrations for the Ones API backend.

## Translations Migration

The translations migration script populates the `TranslationsTable` in DynamoDB with initial translations for Spanish, English, and Portuguese.

### Environment Configuration

The migration requires the following environment variables to be set:

- `AWS_REGION`: AWS region where DynamoDB is deployed (e.g., `us-east-1`)
- `ONES_TRANSLATIONS_TABLE`: Name of the translations table (default: `ones-translations`)
- `DYNAMODB_ENDPOINT`: Optional - DynamoDB endpoint (leave empty for AWS, set to local endpoint for local development)

For AWS environments, the backend will automatically use the default AWS credentials chain (environment variables, AWS credentials file, or IAM role).

### How to Run

#### 1. Development Environment (Local)

If you want to run the migration against a local DynamoDB instance:

```bash
# Set environment variables
export DYNAMODB_ENDPOINT=http://localhost:8000
export AWS_REGION=us-east-1
export ONES_TRANSLATIONS_TABLE=ones-translations

# Run the migration
cd services/ones-api
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
```

#### 2. Development Environment (AWS)

To run the migration against AWS DynamoDB in the development environment:

```bash
# Set environment variables for dev environment
export AWS_REGION=us-east-1
export ONES_TRANSLATIONS_TABLE=ones-dev-translations

# Ensure AWS credentials are configured (via environment variables or AWS credentials file)
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key

# Run the migration
cd services/ones-api
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
```

#### 3. Staging Environment

For the staging environment:

```bash
# Set environment variables for staging
export AWS_REGION=us-east-1
export ONES_TRANSLATIONS_TABLE=ones-staging-translations

# Ensure AWS credentials are configured for staging
export AWS_ACCESS_KEY_ID=staging_access_key
export AWS_SECRET_ACCESS_KEY=staging_secret_key

# Run the migration
cd services/ones-api
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
```

#### 4. Production Environment

For the production environment:

```bash
# Set environment variables for production
export AWS_REGION=us-east-1
export ONES_TRANSLATIONS_TABLE=ones-translations

# Ensure AWS credentials are configured for production
# (In production, this is typically done via IAM roles)
export AWS_ACCESS_KEY_ID=production_access_key
export AWS_SECRET_ACCESS_KEY=production_secret_key

# Run the migration
cd services/ones-api
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
```

### Using AWS CLI Profiles

If you have AWS CLI profiles configured, you can use them instead of setting credentials directly:

```bash
# Use a specific AWS profile
export AWS_PROFILE=my-aws-profile
export AWS_REGION=us-east-1
export ONES_TRANSLATIONS_TABLE=ones-translations

# Run the migration
cd services/ones-api
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations
```

### Using Environment Variables File

Alternatively, you can create a `.env` file in the `services/ones-api` directory:

```bash
# .env file
AWS_REGION=us-east-1
ONES_TRANSLATIONS_TABLE=ones-translations
# DYNAMODB_ENDPOINT= (leave empty for AWS)
```

Then load the environment variables before running the migration:

```bash
# On Linux/Mac
source .env
mvn spring-boot:run -Dspring-boot.run.profiles=migrate-translations

# On Windows PowerShell
Get-Content .env | ForEach-Object { $var = $_.Split('='); [Environment]::SetEnvironmentVariable($var[0], $var[1]) }
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

### Troubleshooting

#### ResourceNotFoundException

If you get a `ResourceNotFoundException`, it means the DynamoDB table doesn't exist in the target environment. Make sure:
- The table name is correct (`ONES_TRANSLATIONS_TABLE`)
- The table has been deployed via CloudFormation in the target environment
- You're connecting to the correct AWS region

#### AccessDeniedException

If you get an `AccessDeniedException`, make sure:
- Your AWS credentials are valid
- The IAM user/role has permissions to read/write to the DynamoDB table
- The credentials are for the correct AWS account

#### NoCredentialsException

If you get a `NoCredentialsException`, ensure:
- AWS credentials are configured (via environment variables, AWS credentials file, or IAM role)
- The credentials have not expired
- You're using the correct AWS profile if using profiles
