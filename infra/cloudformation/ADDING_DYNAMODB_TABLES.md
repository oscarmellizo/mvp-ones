# Adding a New DynamoDB Table

This document describes the steps required to add a new DynamoDB table to the Ones MVP project.

## Overview

The project uses CloudFormation templates to manage AWS infrastructure. When adding a new DynamoDB table, you must update the **main** CloudFormation template file, which is `infra/cloudformation/backend/all.yml`.

**Important:** Do NOT use `infra/cloudformation/backend.yml` - this is a secondary file. The main template is `backend/all.yml`.

## Steps

### 1. Add Table Definition

In `infra/cloudformation/backend/all.yml`, add the table definition in the `Resources` section. Follow this pattern:

```yaml
YourTable:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: !Sub ${StackPrefix}-${Environment}-your-table
    BillingMode: PAY_PER_REQUEST
    Tags:
      - Key: Environment
        Value: !Ref Environment
      - Key: Resource
        Value: YourResource  # Optional: helps with organization
    AttributeDefinitions:
      - AttributeName: hashKey
        AttributeType: S
      # Add RANGE key if needed:
      # - AttributeName: rangeKey
      #   AttributeType: S
    KeySchema:
      - AttributeName: hashKey
        KeyType: HASH
      # Add RANGE key if needed:
      # - AttributeName: rangeKey
      #   KeyType: RANGE
    # Add GlobalSecondaryIndexes if needed:
    # GlobalSecondaryIndexes:
    #   - IndexName: gsi1
    #     KeySchema:
    #       - AttributeName: gsi1pk
    #         KeyType: HASH
    #       - AttributeName: gsi1sk
    #         KeyType: RANGE
    #     Projection:
    #       ProjectionType: ALL
```

### 2. Add IAM Permissions

In the same file (`backend/all.yml`), find the `TaskRole` resource and add your table's ARN to the `ones-dynamodb` policy:

```yaml
Policies:
  - PolicyName: ones-dynamodb
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - dynamodb:PutItem
            - dynamodb:GetItem
            - dynamodb:BatchGetItem
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:DescribeTable
            - dynamodb:DeleteItem
          Resource:
            - !GetAtt EventsTable.Arn
            # ... other tables ...
            - !GetAtt YourTable.Arn  # Add this
            # If your table has indexes, add them too:
            # - !Sub ${YourTable.Arn}/index/*
```

### 3. Add Environment Variable

Find the `TaskDefinition` resource and add the table name as an environment variable:

```yaml
Environment:
  - Name: ONES_EVENTS_TABLE
    Value: !Ref EventsTable
  # ... other tables ...
  - Name: ONES_YOUR_TABLE
    Value: !Ref YourTable  # Add this
```

### 4. Add Stack Output

Add the table name to the `Outputs` section:

```yaml
Outputs:
  # ... other outputs ...
  YourTableName:
    Value: !Ref YourTable  # Add this
```

### 5. Deploy

Commit your changes and run the **Deploy Infra Backend** workflow to deploy the updated CloudFormation stack.

```bash
git add infra/cloudformation/backend/all.yml
git commit -m "Add YourTable to CloudFormation"
git push origin main
```

Then execute the "Deploy Infra Backend" workflow in your CI/CD system.

## Common Mistakes

- **Wrong file:** Always edit `infra/cloudformation/backend/all.yml`, NOT `infra/cloudformation/backend.yml`
- **Missing IAM permissions:** Without IAM permissions, the backend cannot access the table
- **Missing environment variable:** The backend needs the table name in its environment variables
- **Missing index ARNs:** If your table has Global Secondary Indexes, add `!Sub ${YourTable.Arn}/index/*` to the IAM policy
- **Forgetting to deploy:** Changes to CloudFormation templates won't take effect until you run the deploy workflow

## Example: TranslationsTable

For reference, here's how the TranslationsTable was added:

1. Table definition added after EventTemplatesTable (line 387-406)
2. IAM permission added to TaskRole ones-dynamodb policy (line 1050)
3. Environment variable ONES_TRANSLATIONS_TABLE added (line 1202-1203)
4. Output TranslationsTableName added (line 1532-1533)

## Backend Integration

After the table is created, you'll need to:

1. Create the domain model in `services/ones-api/src/main/java/com/ones/api/domain/`
2. Create the DynamoDB repository in `services/ones-api/src/main/java/com/ones/api/adapters/outbound/dynamodb/`
3. Create the use case(s) in `services/ones-api/src/main/java/com/ones/api/application/`
4. Create the REST controller in `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/`
5. Update `application.yml` with the table configuration (if needed)
