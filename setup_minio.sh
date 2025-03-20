#!/bin/bash
set -e

# Check if script is run as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Main menu
show_menu() {
  echo "============================================================="
  echo "                MinIO Distributed Setup"
  echo "============================================================="
  echo "1) Setup MinIO"
  echo "2) Exit"
  echo "============================================================="
  read -p "Enter your choice (1-2): " CHOICE
  
  case "$CHOICE" in
    1)
      setup_minio
      ;;
    2)
      echo "Exiting..."
      exit 0
      ;;
    *)
      error_exit "Invalid choice"
      ;;
  esac
}

# Function to setup MinIO
setup_minio() {
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

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Script is running from: $SCRIPT_DIR"

  MINIO_BASE_DIR="$SCRIPT_DIR/minio"
  CERTS_DIR="$MINIO_BASE_DIR/certs/minio"
  DATA_DIR="$MINIO_BASE_DIR/data"

  echo "Creating directories for MinIO setup..."
  mkdir -p "$CERTS_DIR" || error_exit "Failed to create certificates directory."
  mkdir -p "$DATA_DIR" || error_exit "Failed to create data directory."
  echo "Directories created successfully."
  echo "-------------------------------------------------------------"
  echo

  # ------------------------------------------------------------
  # Step 2: Collecting Domain and Credentials
  # ------------------------------------------------------------
  echo "-------------------------------------------------------------"
  echo "Step 2: Collecting Domain, Credentials, and Bucket Name"
  echo "Description: Prompting for MinIO domain, root user, password, and bucket."
  echo "-------------------------------------------------------------"

  read -p "Enter the domain for MinIO (default: minio.onpremsharing.example.com): " MINIO_DOMAIN
  MINIO_DOMAIN=${MINIO_DOMAIN:-minio.onpremsharing.example.com}

  while true; do
    read -p "Enter MinIO root user [default: minioadmin]: " MINIO_ROOT_USER
    MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
    if [ ${#MINIO_ROOT_USER} -ge 3 ]; then
      break
    else
      echo "MINIO_ROOT_USER length should be at least 3 characters."
    fi
  done

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

  read -p "Enter bucket name [default: data]: " BUCKET_NAME
  BUCKET_NAME=${BUCKET_NAME:-data}

  echo "Domain, credentials, and bucket name collected."
  echo "-------------------------------------------------------------"
  echo

  # ------------------------------------------------------------
  # Step 3: TLS Certificate Retrieval
  # ------------------------------------------------------------
  echo "-------------------------------------------------------------"
  echo "Step 3: TLS Certificate Retrieval"
  echo "Description: Obtaining or using existing TLS certificates via Let's Encrypt."
  echo "-------------------------------------------------------------"

  read -p "Do you want to create a TLS certificate for ${MINIO_DOMAIN} using Let's Encrypt? (y/N): " CREATE_CERT

  if [[ "$CREATE_CERT" =~ ^[Yy]$ ]]; then
    CERT_PATH="/etc/letsencrypt/live/${MINIO_DOMAIN}"
    if sudo test -d "$CERT_PATH"; then
      echo "Certificate for ${MINIO_DOMAIN} already exists. Using existing certificate."
      sudo cp "${CERT_PATH}/privkey.pem" "$CERTS_DIR/private.key" || error_exit "Failed to copy private key."
      sudo cp "${CERT_PATH}/fullchain.pem" "$CERTS_DIR/public.crt" || error_exit "Failed to copy public certificate."
    else
      if ! command -v certbot >/dev/null; then
        echo "Certbot not found. Installing certbot."
        sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
      fi
      echo "Obtaining certificate for ${MINIO_DOMAIN} using standalone mode."
      sudo certbot certonly --non-interactive --agree-tos --standalone -d "${MINIO_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."
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
  echo "Description: Generating docker-compose.yaml for MinIO service."
  echo "-------------------------------------------------------------"

  DOCKER_COMPOSE_FILE="$MINIO_BASE_DIR/docker-compose.yaml"

  cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.7'

services:
  minio:
    container_name: minio
    image: minio/minio:latest
    command: server /data
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "443:9000"
      - "9001:9001"
    volumes:
      - ./data:/data
      - ./certs/minio:/root/.minio/certs
    restart: unless-stopped
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

  # Add lifecycle rule after MinIO is running
  echo "Setting up lifecycle rule for domain ${MINIO_DOMAIN} with root user ${MINIO_ROOT_USER}..."
  docker exec minio mc alias set local https://${MINIO_DOMAIN} "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --insecure
  
  # Create the specified bucket if it doesn't exist
  echo "Creating bucket '${BUCKET_NAME}'..."
  if ! docker exec minio mc ls local/${BUCKET_NAME} --insecure &>/dev/null; then
    docker exec minio mc mb local/${BUCKET_NAME} --insecure || error_exit "Failed to create bucket ${BUCKET_NAME}"
    echo "Bucket '${BUCKET_NAME}' created successfully."
  else
    echo "Bucket '${BUCKET_NAME}' already exists."
  fi
  
  # Add lifecycle rule to the bucket with /downloads prefix
  echo "Adding lifecycle rule to bucket for /downloads prefix..."
  docker exec minio mc ilm add local/${BUCKET_NAME} --expire-days 1 --prefix "/downloads" --insecure

  echo "MinIO setup completed with lifecycle rule configured for '${BUCKET_NAME}/downloads' prefix."
}

# Start the script
show_menu
