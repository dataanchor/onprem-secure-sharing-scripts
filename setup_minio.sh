#!/bin/bash
set -e

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------
echo "============================================================="
echo "                MinIO Setup Automation Script"
echo "This script will configure and start a MinIO instance with"
echo "TLS enabled, using Let's Encrypt for certificates if desired."
echo "============================================================="
echo

# ------------------------------------------------------------
# Step 1: Environment Setup - Creating Required Directories
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 1: Creating Required Directories"
echo "Description: Creating directories for MinIO certificates and data storage."
echo "-------------------------------------------------------------"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script is running from: $SCRIPT_DIR"

# Define base directories relative to the script's location
MINIO_BASE_DIR="$SCRIPT_DIR/minio"
CERTS_DIR="$MINIO_BASE_DIR/certs/minio"
DATA_DIR="$MINIO_BASE_DIR/data"

echo "Creating directories: $CERTS_DIR and $DATA_DIR"
mkdir -p "$CERTS_DIR" || error_exit "Failed to create certificates directory."
mkdir -p "$DATA_DIR" || error_exit "Failed to create data directory."
echo "Directories created successfully."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 2: Collecting Domain and Credentials
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 2: Collecting Domain and Credentials"
echo "Description: Prompting for MinIO domain, root user, and root password."
echo "-------------------------------------------------------------"

# Prompt for MinIO domain
read -p "Enter the domain for MinIO (default: minio.onpremsharing.example.com): " MINIO_DOMAIN
MINIO_DOMAIN=${MINIO_DOMAIN:-minio.onpremsharing.example.com}

# Prompt for MinIO root user with length validation
while true; do
  read -p "Enter MinIO root user [default: minioadmin]: " MINIO_ROOT_USER
  MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
  if [ ${#MINIO_ROOT_USER} -ge 3 ]; then
    break
  else
    echo "MINIO_ROOT_USER length should be at least 3 characters."
  fi
done

# Prompt for MinIO root password securely with length validation
while true; do
  read -sp "Enter MinIO root password (min 8 characters): " MINIO_ROOT_PASSWORD
  echo
  if [ ${#MINIO_ROOT_PASSWORD} -lt 8 ]; then
    echo "Password must be at least 8 characters. Please try again."
    continue
  fi
  read -sp "Confirm MinIO root password: " MINIO_ROOT_PASSWORD_CONFIRM
  echo
  if [[ "$MINIO_ROOT_PASSWORD" == "$MINIO_ROOT_PASSWORD_CONFIRM" ]]; then
    break
  else
    echo "Passwords do not match. Please try again."
  fi
done

echo "Domain and credentials collected."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 3: TLS Certificate Retrieval
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 3: TLS Certificate Retrieval"
echo "Description: Obtaining or using existing TLS certificates via Let's Encrypt."
echo "-------------------------------------------------------------"

# Option to obtain TLS certificate using Let's Encrypt
read -p "Do you want to create a TLS certificate for ${MINIO_DOMAIN} using Let's Encrypt? (y/N): " CREATE_CERT

if [[ "$CREATE_CERT" =~ ^[Yy]$ ]]; then
  CERT_PATH="/etc/letsencrypt/live/${MINIO_DOMAIN}"

  # Check if certificate already exists using sudo for permission
  if sudo test -d "$CERT_PATH"; then
    echo "Certificate for ${MINIO_DOMAIN} already exists. Using existing certificate."
    sudo cp "${CERT_PATH}/privkey.pem" "$CERTS_DIR/private.key" || error_exit "Failed to copy private key."
    sudo cp "${CERT_PATH}/fullchain.pem" "$CERTS_DIR/public.crt" || error_exit "Failed to copy public certificate."
  else
    # Install certbot if not installed
    if ! command -v certbot >/dev/null; then
      echo "Certbot not found. Installing certbot."
      sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
    fi

    echo "Obtaining certificate for ${MINIO_DOMAIN} using standalone mode."
    sudo certbot certonly --non-interactive --agree-tos --standalone -d "${MINIO_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."

    # After attempting to obtain/renew, check if certificate files exist using sudo
    if sudo test -f "${CERT_PATH}/privkey.pem" && sudo test -f "${CERT_PATH}/fullchain.pem"; then
      sudo cp "${CERT_PATH}/privkey.pem" "$CERTS_DIR/private.key" || error_exit "Failed to copy private key."
      sudo cp "${CERT_PATH}/fullchain.pem" "$CERTS_DIR/public.crt" || error_exit "Failed to copy public certificate."
      echo "Certificate obtained and placed in $CERTS_DIR."
    else
      error_exit "Failed to obtain certificate for ${MINIO_DOMAIN}. Exiting."
    fi
  fi
else
  echo "Please place your MinIO TLS certificates (private.key and public.crt) into $CERTS_DIR."
  read -p "Press [Enter] after placing the certificates..."
  # Verify certificates are present
  if [ ! -f "$CERTS_DIR/private.key" ] || [ ! -f "$CERTS_DIR/public.crt" ]; then
    error_exit "Certificates not found in $CERTS_DIR. Exiting."
  fi
fi

echo "TLS certificate setup complete."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 4: Creating Docker Compose File
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 4: Creating Docker Compose File"
echo "Description: Generating a docker-compose.yaml to run MinIO container."
echo "-------------------------------------------------------------"

DOCKER_COMPOSE_FILE="$MINIO_BASE_DIR/docker-compose.yaml"
echo "Creating Docker Compose file at $DOCKER_COMPOSE_FILE."
cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.7'

services:
  minio:
    image: minio/minio
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    command: server /data
    ports:
      - "443:9000"
    volumes:
      - ./data:/data
      - ./certs/minio:/root/.minio/certs
    restart: unless-stopped

volumes:
  minio-data:
EOF

echo "Docker Compose file created successfully."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 5: Starting MinIO Container
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 5: Starting MinIO Container"
echo "Description: Using Docker Compose to launch the MinIO service."
echo "-------------------------------------------------------------"

echo "Starting MinIO container using Docker Compose."
cd "$MINIO_BASE_DIR" || error_exit "Failed to change directory to $MINIO_BASE_DIR."
docker compose up -d || error_exit "Failed to start MinIO container."

echo "Waiting for MinIO to initialize..."
sleep 10

echo "MinIO container started."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 6: Health Check
# ------------------------------------------------------------
echo "-------------------------------------------------------------"
echo "Step 6: Health Check"
echo "Description: Verifying that MinIO is running and healthy."
echo "-------------------------------------------------------------"

HEALTH_URL="https://${MINIO_DOMAIN}/minio/health/ready"
HTTP_STATUS=$(curl -ks -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "Failed to connect")
echo "HTTP Status Code from health check: $HTTP_STATUS"

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "MinIO is healthy and running at https://${MINIO_DOMAIN}"
else
  echo "MinIO health check failed with status code $HTTP_STATUS."
  echo "Please verify your setup."
  exit 1
fi

# ------------------------------------------------------------
# Footer
# ------------------------------------------------------------
echo "============================================================="
echo "                 MinIO Setup Completed"
echo "Your MinIO instance is now up and running."
echo "============================================================="
