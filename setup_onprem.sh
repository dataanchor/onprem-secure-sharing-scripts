#!/bin/bash
set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display error messages and exit
error_exit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

# Function to print section header
print_header() {
  echo -e "\n${BOLD}$1${NC}"
  echo "=============================================="
}

# Function to print success message
print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Function to print info message
print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print warning message
print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to check and install Docker and Docker Compose
check_docker_installation() {
  print_header "Checking Docker Installation"
  
  # Check if Docker or Docker Compose is not installed
  if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    print_warning "Docker or Docker Compose is not installed."
    read -p "Would you like to install Docker and Docker Compose? (y/N): " INSTALL_DOCKER
    
    if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
      print_info "Installing Docker and Docker Compose..."
      
      # Remove old versions if they exist
      sudo apt-get remove docker docker-engine docker.io containerd runc || true
      
      # Update package index
      sudo apt-get update
      
      # Install prerequisites
      sudo apt-get install -y \
          apt-transport-https \
          ca-certificates \
          curl \
          gnupg \
          lsb-release
      
      # Add Docker's official GPG key
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      
      # Set up the stable repository
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
      # Install Docker Engine and Docker Compose
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
      
      print_success "Docker and Docker Compose installed successfully."
    else
      error_exit "Docker and Docker Compose are required to run this script. Please install them and try again."
    fi
  else
    print_success "Docker and Docker Compose are installed."
  fi
}

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  error_exit "This script must be run with sudo privileges. Please run with: sudo $0"
fi

# Check Docker installation before proceeding
check_docker_installation

# ------------------------------------------------------------
# Configure Certificate Renewal Function
# This is a reusable function for both full setup and standalone renewal
# ------------------------------------------------------------
configure_cert_renewal() {
  local domain=$1
  local cert_path=$2
  local ssl_certs_dir=$3
  local base_dir=$4
  
  print_header "Configuring Certificate Renewal"
  
  # Create the deploy hook script in the service directory
  SCRIPTS_DIR="$base_dir/scripts"
  mkdir -p "$SCRIPTS_DIR"
  DEPLOY_HOOK_SCRIPT="$SCRIPTS_DIR/cert-deploy-hook.sh"
  
  # Create the deploy hook script
  sudo tee "$DEPLOY_HOOK_SCRIPT" > /dev/null << EOF
#!/bin/bash
# Let's Encrypt certificate renewal deploy hook for OnPrem Service

# Check if this renewal is for our domain
if [[ "\$RENEWED_DOMAINS" == *"${domain}"* ]]; then
  # Copy the renewed certificates to the service location
  cp "\$RENEWED_LINEAGE/privkey.pem" "$ssl_certs_dir/server.key"
  cp "\$RENEWED_LINEAGE/fullchain.pem" "$ssl_certs_dir/server.crt"
  
  # Restart the container to apply new certificates
  cd "$base_dir" && docker compose restart onprem
  
  # Log the renewal
  echo "\$(date): Renewed certificates for ${domain} and restarted OnPrem service" >> "$base_dir/certificate-renewal.log"
fi
EOF
  
  # Make the deploy hook executable
  sudo chmod +x "$DEPLOY_HOOK_SCRIPT"
  
  # Set up a daily cron job to attempt renewal with deploy hook
  CRON_JOB="0 3 * * * sudo /usr/bin/certbot renew --cert-name ${domain} --deploy-hook $DEPLOY_HOOK_SCRIPT --quiet"
  
  # Check if the cron job already exists before adding it
  if sudo crontab -l 2>/dev/null | grep -q "${domain}"; then
    # Remove old cron job
    sudo crontab -l 2>/dev/null | grep -v "${domain}" | sudo crontab -
    print_warning "Replaced existing cron job for ${domain}"
  fi
  
  # Add the new cron job
  (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
  print_success "Added daily renewal cron job for ${domain} running at 3:00 AM."
  
  print_info "Certificate renewal has been configured:"
  echo "- Deploy hook: $DEPLOY_HOOK_SCRIPT"
  echo "- Daily renewal check at 3:00 AM with deploy hook directly specified"
  echo "- Log file: $base_dir/certificate-renewal.log"
}

# ------------------------------------------------------------
# Setup Function: Full Installation and Configuration
# ------------------------------------------------------------
setup_onprem() {
print_header "Fenixpyre On-Prem Sharing Service Setup Automation"
echo "This script will configure and start the On-Prem Sharing Service"
echo "with PostgreSQL and TLS enabled for the public API."
echo "=============================================="
echo

print_info "Verifying system requirements..."
print_success "Running with sudo privileges"
echo

# ------------------------------------------------------------
# Step 1: Environment Setup - Creating Required Directories
# ------------------------------------------------------------
print_header "Step 1: Creating Required Directories"
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
print_success "Directories created successfully."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 2: mTLS Certificate Placement
# ------------------------------------------------------------
print_header "Step 2: mTLS Certificate Placement"
echo "Description: Prompting to place mTLS certificates provided by support."
echo "-------------------------------------------------------------"

echo "Place your mTLS certificates (server.crt, server.key, ca.crt) into $MTLS_CERTS_DIR."
read -p "Press [Enter] after placing the mTLS certificates..."
if [ ! -f "$MTLS_CERTS_DIR/server.crt" ] || [ ! -f "$MTLS_CERTS_DIR/server.key" ] || [ ! -f "$MTLS_CERTS_DIR/ca.crt" ]; then
  error_exit "mTLS certificates not found in $MTLS_CERTS_DIR. Exiting."
fi
print_success "mTLS certificates confirmed."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 3: Collecting Domain for TLS
# ------------------------------------------------------------
print_header "Step 3: Collecting Domain for TLS"
echo "Description: Prompting for the domain to obtain a TLS certificate."
echo "-------------------------------------------------------------"

read -p "Enter the domain for On-Prem Service (default: onpremsharing.example.com): " ONPREM_DOMAIN
ONPREM_DOMAIN=${ONPREM_DOMAIN:-onpremsharing.example.com}
print_info "Domain set to: $ONPREM_DOMAIN"
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 4: TLS Certificate Retrieval for Public API
# ------------------------------------------------------------
print_header "Step 4: TLS Certificate Retrieval"
echo "Description: Attempting to obtain or use an existing TLS certificate for the public API."
echo "-------------------------------------------------------------"

read -p "Do you want to create a TLS certificate for ${ONPREM_DOMAIN} using Let's Encrypt? (y/N): " CREATE_CERT

if [[ "$CREATE_CERT" =~ ^[Yy]$ ]]; then
  CERT_PATH="/etc/letsencrypt/live/${ONPREM_DOMAIN}"
  if sudo test -d "$CERT_PATH"; then
    print_info "Certificate for ${ONPREM_DOMAIN} already exists. Using existing certificate."
    sudo cp "${CERT_PATH}/privkey.pem" "$SSL_CERTS_DIR/server.key" || error_exit "Failed to copy private key."
    sudo cp "${CERT_PATH}/fullchain.pem" "$SSL_CERTS_DIR/server.crt" || error_exit "Failed to copy public certificate."
  else
    if ! command -v certbot >/dev/null; then
      print_warning "Certbot not found. Installing certbot."
      sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
    fi
    print_info "Obtaining certificate for ${ONPREM_DOMAIN} using standalone mode."
    sudo certbot certonly --non-interactive --agree-tos --standalone -d "${ONPREM_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."
    if sudo test -f "${CERT_PATH}/privkey.pem" && sudo test -f "${CERT_PATH}/fullchain.pem"; then
      sudo cp "${CERT_PATH}/privkey.pem" "$SSL_CERTS_DIR/server.key" || error_exit "Failed to copy private key."
      sudo cp "${CERT_PATH}/fullchain.pem" "$SSL_CERTS_DIR/server.crt" || error_exit "Failed to copy public certificate."
      print_success "Certificate obtained and placed in $SSL_CERTS_DIR."
      
      # Configure certificate renewal using the shared function
      configure_cert_renewal "$ONPREM_DOMAIN" "$CERT_PATH" "$SSL_CERTS_DIR" "$ONPREM_BASE_DIR"
      
    else
      error_exit "Failed to obtain certificate for ${ONPREM_DOMAIN}. Exiting."
    fi
  fi
else
  print_info "Please place your public SSL certificates (server.crt and server.key) into $SSL_CERTS_DIR."
  read -p "Press [Enter] after placing the certificates..."
  if [ ! -f "$SSL_CERTS_DIR/server.key" ] || [ ! -f "$SSL_CERTS_DIR/server.crt" ]; then
    error_exit "Certificates not found in $SSL_CERTS_DIR. Exiting."
  fi
fi
print_success "TLS certificate setup complete."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 5: Collecting Remaining Configuration Details
# ------------------------------------------------------------
print_header "Step 5: Collecting Configuration Details"
echo "Description: Prompting for MinIO details and security tokens."
echo "-------------------------------------------------------------"

# Using fixed PostgreSQL credentials
DB_HOST="postgres"
DB_USER="admin-user"
DB_PASS="admin-pass"
DB_NAME="secure-db"

print_info "Using default PostgreSQL configuration:"
echo "  Host: $DB_HOST"
echo "  Database: $DB_NAME"
echo

read -p "Enter MinIO endpoint (e.g., minio.onpremsharing.example.com): " MINIO_ENDPOINT
read -p "Enter MinIO root user: " MINIO_ID
read -sp "Enter MinIO root password: " MINIO_KEY
echo

while true; do
  read -p "Enter MinIO bucket name: " MINIO_BUCKET
  # Validate bucket name according to MinIO rules
  if [[ "$MINIO_BUCKET" =~ ^[a-z0-9][a-z0-9.-]*$ ]] && [ ${#MINIO_BUCKET} -ge 3 ] && [ ${#MINIO_BUCKET} -le 63 ]; then
    break
  else
    echo "Invalid bucket name. Bucket name must:"
    echo "- Be between 3 and 63 characters long"
    echo "- Start with a letter or number"
    echo "- Contain only lowercase letters, numbers, dots, and hyphens"
    echo "- Be a valid DNS name"
  fi
done

read -p "Enter your FenixPyre organization ID: " CONNECTOR_DOMAIN

# Generate secure tokens instead of prompting
print_info "Generating secure tokens..."
SHARING_TOKEN=$(openssl rand -hex 32)
HMAC_SECRET=$(openssl rand -hex 32)
print_success "Generated secure tokens successfully."

print_success "Configuration details collected."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 6: Generating config.yaml
# ------------------------------------------------------------
print_header "Step 6: Generating config.yaml"
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

print_success "config.yaml generated at $CONFIG_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 7: Creating docker-compose.yaml
# ------------------------------------------------------------
print_header "Step 7: Creating Docker Compose File"
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

print_success "Docker Compose file created at $DOCKER_COMPOSE_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 8: Starting On-Prem Sharing Service
# ------------------------------------------------------------
print_header "Step 8: Starting On-Prem Sharing Service"
echo "Description: Using Docker Compose to launch the service."
echo "-------------------------------------------------------------"

cd "$ONPREM_BASE_DIR" || error_exit "Failed to change directory to $ONPREM_BASE_DIR."
docker compose up -d || error_exit "Failed to start On-Prem Sharing Service containers."

print_info "Waiting 30 seconds for services to initialize..."
sleep 30
print_success "Services started."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 9: Public API Health Check
# ------------------------------------------------------------
print_header "Step 9: Public API Health Check"
echo "Description: Verifying that the public API of the On-Prem Sharing Service is running and healthy."
echo "-------------------------------------------------------------"

HEALTH_URL="https://${ONPREM_DOMAIN}/health"
HTTP_STATUS=$(curl -ks -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "Failed to connect")
echo "HTTP Status Code from public API health check: $HTTP_STATUS"

if [ "$HTTP_STATUS" -eq 200 ]; then
  print_success "Public API is healthy and running at https://${ONPREM_DOMAIN}"
else
  print_warning "Public API health check failed with status code $HTTP_STATUS."
  print_warning "Please verify your setup."
  exit 1
fi
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 10: Private API Health Check
# ------------------------------------------------------------
print_header "Step 10: Private API Health Check"
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
  print_success "Private API is healthy and accessible."
else
  print_warning "Private API health check failed with status code $PRIVATE_API_STATUS."
  print_warning "Please verify your private API setup."
  exit 1
fi
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Step 11: Create Details File
# ------------------------------------------------------------
print_header "Step 11: Creating Details File"
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

print_success "Details file created at $DETAILS_FILE."
echo "-------------------------------------------------------------"
echo

# ------------------------------------------------------------
# Footer
# ------------------------------------------------------------
print_header "On-Prem Sharing Service Setup Completed Successfully"
echo "Your On-Prem Sharing Service is now up and running."
echo "=============================================="

  
  print_success "Full setup completed."
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
# Setup Certificate Renewal Function
# ------------------------------------------------------------
setup_cert_renewal() {
  echo "============================================================="
  echo "         OnPrem Certificate Renewal Automation Setup"
  echo "This option will configure automatic certificate renewal"
  echo "for your existing Let's Encrypt certificates."
  echo "============================================================="
  echo

  # Ask directly for domain name
  read -p "Enter the domain for OnPrem Service: " ONPREM_DOMAIN
  
  # Final check for domain
  if [ -z "$ONPREM_DOMAIN" ]; then
    error_exit "Domain cannot be empty"
  fi
  
  # Check if certificate exists
  CERT_PATH="/etc/letsencrypt/live/${ONPREM_DOMAIN}"
  if [ ! -d "$CERT_PATH" ]; then
    echo "Certificate for ${ONPREM_DOMAIN} not found at $CERT_PATH"
    read -p "Would you like to create a new certificate for ${ONPREM_DOMAIN}? (Y/n): " CREATE_CERT
    
    if [[ ! "$CREATE_CERT" =~ ^[Nn]$ ]]; then
      # Check if certbot is installed
      if ! command -v certbot >/dev/null; then
        echo "Certbot not found. Installing certbot..."
        sudo apt-get update && sudo apt-get install -y certbot || error_exit "Failed to install Certbot."
      fi
      
      # Get SSL certificate path
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      ONPREM_BASE_DIR="$SCRIPT_DIR/onpremsharing"
      SSL_CERTS_DIR="$ONPREM_BASE_DIR/certs/ssl"
      
      if [ ! -d "$SSL_CERTS_DIR" ]; then
        echo "Creating SSL certificates directory..."
        mkdir -p "$SSL_CERTS_DIR" || error_exit "Failed to create SSL certificates directory."
      fi
      
      # Obtain certificate
      echo "Obtaining certificate for ${ONPREM_DOMAIN} using standalone mode."
      sudo certbot certonly --non-interactive --agree-tos --standalone -d "${ONPREM_DOMAIN}" --register-unsafely-without-email || error_exit "Certbot failed to obtain certificate."
      
      if sudo test -f "${CERT_PATH}/privkey.pem" && sudo test -f "${CERT_PATH}/fullchain.pem"; then
        echo "Certificate obtained successfully."
      else
        error_exit "Failed to obtain certificate for ${ONPREM_DOMAIN}. Exiting."
      fi
    else
      error_exit "Cannot proceed without a valid certificate."
    fi
  else
    echo "Certificate found for ${ONPREM_DOMAIN}"
  fi
  
  # Get SSL certificate path in OnPrem service
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ONPREM_BASE_DIR="$SCRIPT_DIR/onpremsharing"
  SSL_CERTS_DIR="$ONPREM_BASE_DIR/certs/ssl"
  
  if [ ! -d "$SSL_CERTS_DIR" ]; then
    echo "Creating SSL certificates directory..."
    mkdir -p "$SSL_CERTS_DIR" || error_exit "Failed to create SSL certificates directory."
  fi
  
  # Copy current certificates to OnPrem service location
  echo "Copying current certificates to OnPrem service location..."
  sudo cp "${CERT_PATH}/privkey.pem" "$SSL_CERTS_DIR/server.key" || error_exit "Failed to copy private key."
  sudo cp "${CERT_PATH}/fullchain.pem" "$SSL_CERTS_DIR/server.crt" || error_exit "Failed to copy public certificate."
  
  # Configure certificate renewal using the shared function
  configure_cert_renewal "$ONPREM_DOMAIN" "$CERT_PATH" "$SSL_CERTS_DIR" "$ONPREM_BASE_DIR"
  
  # Run validation script if available
  if [ -f "$SCRIPT_DIR/validate_onprem_renewal.sh" ]; then
    echo "Validation script found. You can verify your setup with:"
    echo "sudo $SCRIPT_DIR/validate_onprem_renewal.sh"
  fi
  
  echo "============================================================="
  echo "Certificate renewal automation setup completed successfully."
  echo "============================================================="
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
echo "5) Setup Certificate Renewal"
echo "============================================================="
read -p "Enter your choice (1, 2, 3, 4, or 5): " choice

case "$choice" in
  1) setup_onprem ;;
  2) verify_onprem ;;
  3) extract_credentials ;;
  4) create_credentials_file ;;
  5) setup_cert_renewal ;;
  *) echo "Invalid choice. Exiting." ; exit 1 ;;
esac
