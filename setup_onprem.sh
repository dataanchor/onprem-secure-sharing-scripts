#!/bin/bash
set -e

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  error_exit "This script must be run with sudo privileges. Please run with: sudo $0"
fi

# ------------------------------------------------------------
# Setup Function: Full Installation and Configuration
# ------------------------------------------------------------
setup_onprem() {
echo "Starting full setup..."

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------
echo "============================================================="
echo "      Fenixpyre On-Prem Sharing Service Setup Automation"
echo "This script will configure and start the On-Prem Sharing Service"
echo "with PostgreSQL and TLS enabled for the public API."
echo "============================================================="
echo

echo "Verifying system requirements..."
echo "✓ Running with sudo privileges"
echo

# ------------------------------------------------------------
# Step 1: Environment Setup - Creating Required Directories
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 1: Creating Required Directories"
echo "Description: Creating directories for service configuration, certificates, and logs."
echo "-------------------------------------------------------------"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script is running from: $SCRIPT_DIR"

ONPREM_BASE_DIR="$SCRIPT_DIR/onpremsharing"
MTLS_CERTS_DIR="$ONPREM_BASE_DIR/certs/mtls"
SSL_CERTS_DIR="$ONPREM_BASE_DIR/certs/ssl"
LOGS_DIR="$ONPREM_BASE_DIR/logs"

echo "Creating directories: $MTLS_CERTS_DIR, $SSL_CERTS_DIR, and $LOGS_DIR"
mkdir -p "$MTLS_CERTS_DIR" || error_exit "Failed to create mTLS certificates directory."
mkdir -p "$SSL_CERTS_DIR" || error_exit "Failed to create SSL certificates directory."
mkdir -p "$LOGS_DIR" || error_exit "Failed to create logs directory."
echo "Directories created successfully."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 2: mTLS Certificate Placement
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 2: mTLS Certificate Placement"
echo "Description: Prompting to place mTLS certificates provided by support."
echo "-------------------------------------------------------------"

echo "Place your mTLS certificates (server.crt, server.key, ca.crt) into $MTLS_CERTS_DIR."
read -p "Press [Enter] after placing the mTLS certificates..."
if [ ! -f "$MTLS_CERTS_DIR/server.crt" ] || [ ! -f "$MTLS_CERTS_DIR/server.key" ] || [ ! -f "$MTLS_CERTS_DIR/ca.crt" ]; then
  error_exit "mTLS certificates not found in $MTLS_CERTS_DIR. Exiting."
fi
echo "mTLS certificates confirmed."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 3: Collecting Domain for TLS
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 3: Collecting Domain for TLS"
echo "Description: Prompting for the domain to obtain a TLS certificate."
echo "-------------------------------------------------------------"

read -p "Enter the domain for On-Prem Service (default: onpremsharing.example.com): " ONPREM_DOMAIN
ONPREM_DOMAIN=${ONPREM_DOMAIN:-onpremsharing.example.com}
echo "Domain set to: $ONPREM_DOMAIN"
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 4: TLS Certificate Retrieval for Public API
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 4: TLS Certificate Retrieval"
echo "Description: Attempting to obtain or use an existing TLS certificate for the public API."
echo "-------------------------------------------------------------"

read -p "Do you want to create a TLS certificate for ${ONPREM_DOMAIN} using Let's Encrypt? (y/N): " CREATE_CERT

if [[ "$CREATE_CERT" =~ ^[Yy]$ ]]; then
  CERT_PATH="/etc/letsencrypt/live/${ONPREM_DOMAIN}"
  if sudo test -d "$CERT_PATH"; then
    echo "Certificate for ${ONPREM_DOMAIN} already exists. Using existing certificate."
    sudo cp "${CERT_PATH}/privkey.pem" "$SSL_CERTS_DIR/server.key" || error_exit "Failed to copy private key."
    sudo cp "${CERT_PATH}/fullchain.pem" "$SSL_CERTS_DIR/server.crt" || error_exit "Failed to copy public certificate."
  else
    if ! command -v certbot >/dev/null; then
      echo "Certbot not found. Installing certbot."
      sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
    fi
    echo "Obtaining certificate for ${ONPREM_DOMAIN} using standalone mode."
    sudo certbot certonly --non-interactive --agree-tos --standalone -d "${ONPREM_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."
    if sudo test -f "${CERT_PATH}/privkey.pem" && sudo test -f "${CERT_PATH}/fullchain.pem"; then
      sudo cp "${CERT_PATH}/privkey.pem" "$SSL_CERTS_DIR/server.key" || error_exit "Failed to copy private key."
      sudo cp "${CERT_PATH}/fullchain.pem" "$SSL_CERTS_DIR/server.crt" || error_exit "Failed to copy public certificate."
      echo "Certificate obtained and placed in $SSL_CERTS_DIR."
    else
      error_exit "Failed to obtain certificate for ${ONPREM_DOMAIN}. Exiting."
    fi
  fi
else
  echo "Please place your public SSL certificates (server.crt and server.key) into $SSL_CERTS_DIR."
  read -p "Press [Enter] after placing the certificates..."
  if [ ! -f "$SSL_CERTS_DIR/server.key" ] || [ ! -f "$SSL_CERTS_DIR/server.crt" ]; then
    error_exit "Certificates not found in $SSL_CERTS_DIR. Exiting."
  fi
fi
echo "TLS certificate setup complete."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 5: Collecting Remaining Configuration Details
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 5: Collecting Configuration Details"
echo "Description: Prompting for MinIO details and security tokens."
echo "-------------------------------------------------------------"

# Using fixed PostgreSQL credentials
DB_HOST="postgres"
DB_USER="admin-user"
DB_PASS="admin-pass"
DB_NAME="secure-db"

echo "Using default PostgreSQL configuration:"
echo "  Host: $DB_HOST"
echo "  Database: $DB_NAME"
echo

read -p "Enter MinIO endpoint (e.g., minio.onpremsharing.example.com): " MINIO_ENDPOINT
read -p "Enter MinIO Access Key ID: " MINIO_ID
read -sp "Enter MinIO Secret Access Key: " MINIO_KEY
echo
read -p "Enter MinIO bucket name: " MINIO_BUCKET

read -p "Enter Connector Domain: " CONNECTOR_DOMAIN
read -p "Enter Sharing Service Token: " SHARING_TOKEN
read -p "Enter HMAC Secret: " HMAC_SECRET

echo "Configuration details collected."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 6: Generating config.yaml
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 6: Generating config.yaml"
echo "Description: Creating configuration file for On-Prem Sharing Service."
echo "-------------------------------------------------------------"

CONFIG_FILE="$ONPREM_BASE_DIR/config.yaml"
cat > "$CONFIG_FILE" <<EOF
public_port: "443"
private_port: "8080"
host_url: "https://${ONPREM_DOMAIN}"

db:
  host: ${DB_HOST}
  port: "5432"
  user: ${DB_USER}
  password: ${DB_PASS}
  name: ${DB_NAME}

minio:
  endpoint: "${MINIO_ENDPOINT}"
  access_key_id: "${MINIO_ID}"
  secret_access_key: "${MINIO_KEY}"
  bucket_name: "${MINIO_BUCKET}"

certificate:
  cert_file: "mtls/certs/server.crt"
  key_file: "mtls/certs/server.key"
  ca_file: "mtls/certs/ca.crt"

public_certificate:
  cert_file: "ssl/certs/server.crt"
  key_file: "ssl/certs/server.key"

connector_domain: "${CONNECTOR_DOMAIN}"
sharing_service_token: "${SHARING_TOKEN}"
hmac_secret: "${HMAC_SECRET}"
EOF

echo "config.yaml generated at $CONFIG_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 7: Creating docker-compose.yaml
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 7: Creating Docker Compose File"
echo "Description: Generating docker-compose.yaml to run On-Prem Sharing Service and PostgreSQL."
echo "-------------------------------------------------------------"

DOCKER_COMPOSE_FILE="$ONPREM_BASE_DIR/docker-compose.yaml"
cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.7'

services:
  postgres:
    image: postgres:14
    restart: always
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  onprem:
    image: datanchorio/fenixpyre-onprem-secure-sharing-service:1.0
    restart: on-failure
    ports:
      - "8080:8080"
      - "443:443"
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./logs/:/app/logs/
      - ./certs/mtls:/app/mtls/certs
      - ./certs/ssl:/app/ssl/certs
    depends_on:
      - postgres

volumes:
  pgdata:
EOF

echo "Docker Compose file created at $DOCKER_COMPOSE_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 8: Starting On-Prem Sharing Service
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 8: Starting On-Prem Sharing Service"
echo "Description: Using Docker Compose to launch the service."
echo "-------------------------------------------------------------"

cd "$ONPREM_BASE_DIR" || error_exit "Failed to change directory to $ONPREM_BASE_DIR."
docker compose up -d || error_exit "Failed to start On-Prem Sharing Service containers."

echo "Waiting for services to initialize..."
sleep 15
echo "Services started."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 9: Public API Health Check
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 9: Public API Health Check"
echo "Description: Verifying that the public API of the On-Prem Sharing Service is running and healthy."
echo "-------------------------------------------------------------"

HEALTH_URL="https://${ONPREM_DOMAIN}/health"
HTTP_STATUS=$(curl -ks -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "Failed to connect")
echo "HTTP Status Code from public API health check: $HTTP_STATUS"

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Public API is healthy and running at https://${ONPREM_DOMAIN}"
else
  echo "Public API health check failed with status code $HTTP_STATUS."
  echo "Please verify your setup."
  exit 1
fi
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 10: Private API Health Check
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 10: Private API Health Check"
echo "Description: Verifying that the private API is running and healthy using mTLS."
echo "-------------------------------------------------------------"

read -p "Enter the public IP address of this VM: " PUBLIC_IP

# Reuse mTLS certificates placed in Step 2 for client authentication
CLIENT_CERT="$MTLS_CERTS_DIR/server.crt"
CLIENT_KEY="$MTLS_CERTS_DIR/server.key"

PRIVATE_API_URL="https://${PUBLIC_IP}:8080/health"
PRIVATE_API_STATUS=$(curl -k \
  --cert "$CLIENT_CERT" \
  --key "$CLIENT_KEY" \
  -H "d-user-id: test@example.com" \
  -H "d-agent-id: test-agent-001" \
  -H "d-org-id: test-org-001" \
  -o /dev/null \
  -w "%{http_code}" \
  "$PRIVATE_API_URL" || echo "Failed")
echo "HTTP Status Code from private API health check: $PRIVATE_API_STATUS"

if [ "$PRIVATE_API_STATUS" -eq 200 ]; then
  echo "Private API is healthy and accessible."
else
  echo "Private API health check failed with status code $PRIVATE_API_STATUS."
  echo "Please verify your private API setup."
  exit 1
fi
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 11: Create Details File
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 11: Creating Details File"
echo "Description: Creating a file with public URL, private URL, sharing service token, and HMAC token."
echo "-------------------------------------------------------------"

DETAILS_FILE="$ONPREM_BASE_DIR/onprem_details.txt"
PRIVATE_URL="https://${PUBLIC_IP}:8080"

cat > "$DETAILS_FILE" <<EOF
Public URL: https://${ONPREM_DOMAIN}
Private URL: ${PRIVATE_URL}
Sharing Service Token: ${SHARING_TOKEN}
HMAC Secret: ${HMAC_SECRET}
EOF

echo "Details file created at $DETAILS_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Footer
# ------------------------------------------------------------
echo "============================================================="
echo "       On-Prem Sharing Service Setup Completed Successfully"
echo "Your On-Prem Sharing Service is now up and running."
echo "============================================================="

  
  echo "Full setup completed."
}

# ------------------------------------------------------------
# Verify Function: Health Checks Only
# ------------------------------------------------------------
verify_onprem() {
  echo "============================================================="
  echo "             On-Prem Sharing Service Verification"
  echo "This mode will verify the health of both public and private"
  echo "APIs of your On-Prem Sharing Service deployment."
  echo "============================================================="
  echo

  echo "-------------------------------------------------------------"
  echo "Step 1: Collecting Verification Details"
  echo "Description: Prompting for domain and public IP for health checks."
  echo "-------------------------------------------------------------"

  read -p "Enter the domain of the On-Prem Service: " ONPREM_DOMAIN
  read -p "Enter the public IP address of the VM for private API access: " PUBLIC_IP

  echo "Domain: $ONPREM_DOMAIN"
  echo "Public IP: $PUBLIC_IP"
  echo "-------------------------------------------------------------"
  echo

  echo "-------------------------------------------------------------"
  echo "Step 2: Public API Health Check"
  echo "Description: Verifying that the public API is running and healthy."
  echo "-------------------------------------------------------------"

  PUBLIC_HEALTH_URL="https://${ONPREM_DOMAIN}/health"
  PUBLIC_HTTP_STATUS=$(curl -ks -o /dev/null -w "%{http_code}" "$PUBLIC_HEALTH_URL" || echo "Failed")

  echo "HTTP Status Code from public API health check: $PUBLIC_HTTP_STATUS"

  if [ "$PUBLIC_HTTP_STATUS" -eq 200 ]; then
    echo "Public API is healthy and running at https://${ONPREM_DOMAIN}"
  else
    echo "Public API health check failed with status code $PUBLIC_HTTP_STATUS."
    exit 1
  fi
  echo "-------------------------------------------------------------"
  echo

  echo "-------------------------------------------------------------"
  echo "Step 3: Private API Health Check"
  echo "Description: Verifying that the private API is running and healthy using mTLS."
  echo "-------------------------------------------------------------"

  CLIENT_CERT="./onpremsharing/certs/mtls/server.crt"
  CLIENT_KEY="./onpremsharing/certs/mtls/server.key"

  PRIVATE_API_URL="https://${PUBLIC_IP}:8080/health"
  PRIVATE_API_STATUS=$(curl -k \
    --cert "$CLIENT_CERT" \
    --key "$CLIENT_KEY" \
    -H "d-user-id: test@example.com" \
    -H "d-agent-id: test-agent-001" \
    -H "d-org-id: test-org-001" \
    -o /dev/null \
    -w "%{http_code}" \
    "$PRIVATE_API_URL" || echo "Failed")

  echo "HTTP Status Code from private API health check: $PRIVATE_API_STATUS"

  if [ "$PRIVATE_API_STATUS" -eq 200 ]; then
    echo "Private API is healthy and accessible at ${PRIVATE_API_URL}."
  else
    echo "Private API health check failed with status code $PRIVATE_API_STATUS."
    exit 1
  fi
  echo "-------------------------------------------------------------"
  echo

  echo "============================================================="
  echo "        Verification Completed"
  echo "Please review the above results for API health status."
  echo "============================================================="
}

# ------------------------------------------------------------
# Extract Credentials Function
# ------------------------------------------------------------
extract_credentials() {
  echo "============================================================="
  echo "                Extracting Credentials"
  echo "============================================================="

  DETAILS_FILE="./onpremsharing/onprem_details.txt"
  
  if [ -f "$DETAILS_FILE" ]; then
      echo "Credentials found:"
      cat "$DETAILS_FILE"
  else
      echo "No credentials details found at $DETAILS_FILE."
  fi
  
  echo "============================================================="
}

# ------------------------------------------------------------
# Create Credentials File Function
# ------------------------------------------------------------
create_credentials_file() {
  echo "============================================================="
  echo "           Create Credentials File"
  echo "This option will extract details from config.yaml and prompt"
  echo "for any missing information to create the credentials file."
  echo "============================================================="
  echo

  # Determine base directory
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ONPREM_BASE_DIR="$SCRIPT_DIR/onpremsharing"
  CONFIG_FILE="$ONPREM_BASE_DIR/config.yaml"

  # Extract details from config.yaml
  HOST_URL=$(grep '^host_url:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
  ONPREM_DOMAIN=${HOST_URL#https://}
  SHARING_SERVICE_TOKEN=$(grep '^sharing_service_token:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
  HMAC_SECRET=$(grep '^hmac_secret:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

  echo "Extracted Domain: $ONPREM_DOMAIN"
  echo "Extracted Sharing Service Token: $SHARING_SERVICE_TOKEN"
  echo "Extracted HMAC Secret: [HIDDEN for security]"
  
  read -p "Enter the public IP address of the VM for private API access: " PUBLIC_IP

  DETAILS_FILE="$ONPREM_BASE_DIR/onprem_details.txt"
  PRIVATE_URL="https://${PUBLIC_IP}:8080"

  cat > "$DETAILS_FILE" <<EOF
Public URL: ${HOST_URL}
Private URL: ${PRIVATE_URL}
Sharing Service Token: ${SHARING_SERVICE_TOKEN}
HMAC Secret: ${HMAC_SECRET}
EOF

  echo "Credentials file created at $DETAILS_FILE."
  echo "============================================================="
  echo
}

# ------------------------------------------------------------
# Main Menu: Choose Mode
# ------------------------------------------------------------
echo "============================================================="
echo "  On-Prem Sharing Service - Choose an Option"
echo "1) Full Setup"
echo "2) Verify Deployment"
echo "3) Extract Credentials"
echo "4) Create Credentials File"
echo "============================================================="
read -p "Enter your choice (1, 2, 3, or 4): " choice

case "$choice" in
  1) setup_onprem ;;
  2) verify_onprem ;;
  3) extract_credentials ;;
  4) create_credentials_file ;;
  *) echo "Invalid choice. Exiting." ; exit 1 ;;
esac
