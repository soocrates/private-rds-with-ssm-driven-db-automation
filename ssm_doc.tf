# =========================================================================
# STAGE 1: CONFIGURE THE INSTANCE (runs only ONCE)
# =========================================================================

# This SSM Document's only job is to install software.
resource "aws_ssm_document" "install_tools" {
  name            = "InstallDBWorkerTools-Ubuntu"
  document_format = "YAML"
  document_type   = "Command"

  content = <<-YAML
schemaVersion: "2.2"
description: "Installs all necessary tools for the DB worker instance."
mainSteps:
  - action: "aws:runShellScript"
    name: "InstallTools"
    inputs:
      runCommand:
        - |
          #!/bin/bash
          set -e
          echo "--- Waiting for OS to stabilize and release APT lock..."
          while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
             echo "APT lock is held, waiting 15 seconds..."
             sleep 15
          done

          echo "--- Installing prerequisite tools..."
          export DEBIAN_FRONTEND=noninteractive
          sudo apt-get update -y
          sudo apt-get install -y curl unzip jq postgresql-client

          echo "--- Installing/Updating AWS CLI v2..."
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -o awscliv2.zip
          sudo ./aws/install --update

          echo "--- All tools installed successfully ---"
YAML
}

# =========================================================================
# STAGE 2: CREATE DATABASES (runs in parallel for each DB)
# =========================================================================

# This SSM document is now IDEMPOTENT. It can be run multiple times safely.
resource "aws_ssm_document" "db_creator" {
  name            = "CreatePostgresDBAndUserWithVector"
  document_format = "YAML"
  document_type   = "Command"

  content = <<-YAML
schemaVersion: "2.2"
description: "Idempotently creates a PostgreSQL database and user. Skips creation if they already exist."
parameters:
  NewDBName:
    type: String
  NewUserPasswordSecretArn:
    type: String
  MasterSecretArn:
    type: String
  DBHost:
    type: String
mainSteps:
  - action: "aws:runShellScript"
    name: "CreateDatabase"
    inputs:
      runCommand:
        - |
          #!/bin/bash
          set -e
          echo "--- Starting idempotent DB setup for {{ NewDBName }} ---"

          # This part assumes tools are already installed by the configure_instance stage.

          echo "Step 1: Fetching credentials..."
          MASTER_SECRET=$(aws secretsmanager get-secret-value --secret-id "{{ MasterSecretArn }}" --query SecretString --output text)
          NEW_USER_SECRET=$(aws secretsmanager get-secret-value --secret-id "{{ NewUserPasswordSecretArn }}" --query SecretString --output text)

          echo "Step 2: Preparing shell variables..."
          export DB_MASTER_USER=$(echo $MASTER_SECRET | jq -r .username)
          export PGPASSWORD=$(echo $MASTER_SECRET | jq -r .password)
          DB_HOST="{{ DBHost }}"
          NEW_DB_NAME="{{ NewDBName }}"
          NEW_DB_USER="$${NEW_DB_NAME}_user"
          NEW_DB_PASSWORD=$(echo $NEW_USER_SECRET | jq -r .password)

          # =========================================================================
          # LOGIC FOR THE ROLE (USER)
          # =========================================================================
          echo "Step 3: Checking if role '$NEW_DB_USER' already exists..."
          # The -t flag gives tuples-only output. psql returns exit code 0 even if no rows are found.
          # We check if the result string is empty (-z).
          if [[ -z $(psql -h $DB_HOST -U $DB_MASTER_USER -d postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname = '$NEW_DB_USER'") ]]; then
            echo "Role '$NEW_DB_USER' not found. Creating..."
            psql -h $DB_HOST -U $DB_MASTER_USER -d postgres -c "CREATE ROLE \"$NEW_DB_USER\" WITH LOGIN PASSWORD '$NEW_DB_PASSWORD';"
            echo "Role '$NEW_DB_USER' created."
          else
            echo "Role '$NEW_DB_USER' already exists. Skipping role creation."
          fi

          # =========================================================================
          # LOGIC FOR THE DATABASE
          # =========================================================================
          echo "Step 4: Checking if database '$NEW_DB_NAME' already exists..."
          if [[ -z $(psql -h $DB_HOST -U $DB_MASTER_USER -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '$NEW_DB_NAME'") ]]; then
            echo "Database '$NEW_DB_NAME' not found. Creating..."
            psql -h $DB_HOST -U $DB_MASTER_USER -d postgres -c "CREATE DATABASE \"$NEW_DB_NAME\" OWNER \"$NEW_DB_USER\";"
            echo "Database '$NEW_DB_NAME' created."
          else
            echo "Database '$NEW_DB_NAME' already exists. Skipping database creation."
          fi

          # =========================================================================
          # LOGIC FOR THE EXTENSION (built-in)
          # =========================================================================
          echo "Step 5: Ensuring 'vector' extension exists in database '$NEW_DB_NAME'..."
          psql -h $DB_HOST -U $DB_MASTER_USER -d $NEW_DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;"
          echo "Extension 'vector' is present."

          echo "--- SUCCESS: Idempotent setup for database $NEW_DB_NAME is complete. ---"
YAML
}