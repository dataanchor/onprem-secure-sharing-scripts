#!/bin/bash
set -e

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check if script is run as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

# Configure Certificate Renewal Function
# This is a reusable function for both full setup and standalone renewal
configure_cert_renewal() {
  local domain=$1
  local cert_path=$2
  local certs_dir=$3
  local base_dir=$4
  
  echo "Configuring certificate renewal..."
  
  # Create the deploy hook script in the service directory
  SCRIPTS_DIR="$base_dir/scripts"
  mkdir -p "$SCRIPTS_DIR"
  DEPLOY_HOOK_SCRIPT="$SCRIPTS_DIR/cert-deploy-hook.sh"
  
  # Create the deploy hook script
  sudo tee "$DEPLOY_HOOK_SCRIPT" > /dev/null << EOF
#!/bin/bash
# Let's Encrypt certificate renewal deploy hook for MinIO Service

# Check if this renewal is for our domain
if [[ "\$RENEWED_DOMAINS" == *"${domain}"* ]]; then
  # Copy the renewed certificates to the service location
  cp "\$RENEWED_LINEAGE/privkey.pem" "$certs_dir/private.key"
  cp "\$RENEWED_LINEAGE/fullchain.pem" "$certs_dir/public.crt"
  
  # Restart the container to apply new certificates
  cd "$base_dir" && docker compose restart minio
  
  # Log the renewal
  echo "\$(date): Renewed certificates for ${domain} and restarted MinIO service" >> "$base_dir/certificate-renewal.log"
fi
EOF
  
  # Make the deploy hook executable
  sudo chmod +x "$DEPLOY_HOOK_SCRIPT"
  
  # Set up a daily cron job to attempt renewal with deploy hook
  CRON_JOB="0 3 * * * /usr/bin/certbot renew --cert-name ${domain} --deploy-hook $DEPLOY_HOOK_SCRIPT --quiet"
  
  # Check if the cron job already exists before adding it
  if sudo crontab -l 2>/dev/null | grep -q "${domain}"; then
    # Remove old cron job
    sudo crontab -l 2>/dev/null | grep -v "${domain}" | sudo crontab -
    echo "Replaced existing cron job for ${domain}"
  fi
  
  # Add the new cron job
  (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
  echo "Added daily renewal cron job for ${domain} running at 3:00 AM."
  
  echo "Certificate renewal has been configured:"
  echo "- Deploy hook: $DEPLOY_HOOK_SCRIPT"
  echo "- Daily renewal check at 3:00 AM with deploy hook directly specified"
  echo "- Log file: $base_dir/certificate-renewal.log"
}

# Main menu
show_menu() {
  echo "============================================================="
  echo "                MinIO Distributed Setup"
  echo "============================================================="
  echo "1) Setup MinIO"
  echo "2) Setup Certificate Renewal"
  echo "3) Exit"
  echo "============================================================="
  read -p "Enter your choice (1-3): " CHOICE
  
  case "$CHOICE" in
    1)
      setup_minio
      ;;
    2)
      setup_cert_renewal
      ;;
    3)
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
        
        # Configure certificate renewal using the shared function
        configure_cert_renewal "$MINIO_DOMAIN" "$CERT_PATH" "$CERTS_DIR" "$MINIO_BASE_DIR"
        
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

# Setup certificate renewal function
setup_cert_renewal() {
  echo "============================================================="
  echo "         MinIO Certificate Renewal Automation Setup"
  echo "This option will configure automatic certificate renewal"
  echo "for your existing Let's Encrypt certificates."
  echo "============================================================="
  echo

  # Ask directly for domain name
  read -p "Enter the domain for MinIO Service: " MINIO_DOMAIN
  
  # Final check for domain
  if [ -z "$MINIO_DOMAIN" ]; then
    error_exit "Domain cannot be empty"
  fi
  
  # Check if certificate exists
  CERT_PATH="/etc/letsencrypt/live/${MINIO_DOMAIN}"
  if [ ! -d "$CERT_PATH" ]; then
    echo "Certificate for ${MINIO_DOMAIN} not found at $CERT_PATH"
    read -p "Would you like to create a new certificate for ${MINIO_DOMAIN}? (Y/n): " CREATE_CERT
    
    if [[ ! "$CREATE_CERT" =~ ^[Nn]$ ]]; then
      # Check if certbot is installed
      if ! command -v certbot >/dev/null; then
        echo "Certbot not found. Installing certbot..."
        sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
      fi
      
      # Get MinIO certificate path
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      MINIO_BASE_DIR="$SCRIPT_DIR/minio"
      CERTS_DIR="$MINIO_BASE_DIR/certs/minio"
      
      if [ ! -d "$CERTS_DIR" ]; then
        echo "Creating MinIO certificates directory..."
        mkdir -p "$CERTS_DIR" || error_exit "Failed to create MinIO certificates directory."
      fi
      
      # Obtain certificate
      echo "Obtaining certificate for ${MINIO_DOMAIN} using standalone mode."
      sudo certbot certonly --non-interactive --agree-tos --standalone -d "${MINIO_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."
      
      if sudo test -f "${CERT_PATH}/privkey.pem" && sudo test -f "${CERT_PATH}/fullchain.pem"; then
        echo "Certificate obtained successfully."
      else
        error_exit "Failed to obtain certificate for ${MINIO_DOMAIN}. Exiting."
      fi
    else
      error_exit "Cannot proceed without a valid certificate."
    fi
  else
    echo "Certificate found for ${MINIO_DOMAIN}"
  fi
  
  # Get MinIO certificate path
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  MINIO_BASE_DIR="$SCRIPT_DIR/minio"
  CERTS_DIR="$MINIO_BASE_DIR/certs/minio"
  
  if [ ! -d "$CERTS_DIR" ]; then
    echo "Creating MinIO certificates directory..."
    mkdir -p "$CERTS_DIR" || error_exit "Failed to create MinIO certificates directory."
  fi
  
  # Copy current certificates to MinIO service location
  echo "Copying current certificates to MinIO service location..."
  sudo cp "${CERT_PATH}/privkey.pem" "$CERTS_DIR/private.key" || error_exit "Failed to copy private key."
  sudo cp "${CERT_PATH}/fullchain.pem" "$CERTS_DIR/public.crt" || error_exit "Failed to copy public certificate."
  
  # Configure certificate renewal using the shared function
  configure_cert_renewal "$MINIO_DOMAIN" "$CERT_PATH" "$CERTS_DIR" "$MINIO_BASE_DIR"
  
  # Run validation script if available
  if [ -f "$SCRIPT_DIR/validate_minio_renewal.sh" ]; then
    echo "Validation script found. You can verify your setup with:"
    echo "sudo $SCRIPT_DIR/validate_minio_renewal.sh"
  fi
  
  echo "============================================================="
  echo "Certificate renewal automation setup completed successfully."
  echo "============================================================="
}

# Start the script
show_menu
