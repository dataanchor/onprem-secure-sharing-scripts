#!/bin/bash
# MinIO Certificate Renewal Validation Script
# Checks that Let's Encrypt automation is set up correctly for MinIO service

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
  echo -e "\n${BOLD}$1${NC}"
  echo "=============================================="
}

# Function to check success/failure
check_status() {
  if [ $1 -eq 0 ]; then
    echo -e "  ${GREEN}✓ $2${NC}"
    return 0
  else
    echo -e "  ${RED}✗ $3${NC}"
    return 1
  fi
}

# Check for sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo privileges:${NC}"
  echo "sudo $0"
  exit 1
fi

print_header "MinIO Certificate Renewal Validation Tool"
echo "This script will verify that your Let's Encrypt certificate"
echo "renewal automation is set up correctly for MinIO service."

# Verify MinIO service is running
if ! docker ps 2>/dev/null | grep -q "minio"; then
  echo -e "${YELLOW}Warning: MinIO container not detected as running.${NC}"
  read -p "Continue anyway? (y/N): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Ask directly for domain name
read -p "Enter the domain for MinIO Service: " MINIO_DOMAIN

# Check if domain is empty
if [ -z "$MINIO_DOMAIN" ]; then
  echo -e "${RED}Domain cannot be empty. Exiting.${NC}"
  exit 1
fi

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIO_BASE_DIR="$SCRIPT_DIR/minio"
CERTS_DIR="$MINIO_BASE_DIR/certs/minio"
SCRIPTS_DIR="$MINIO_BASE_DIR/scripts"
LOCAL_DEPLOY_HOOK="$SCRIPTS_DIR/cert-deploy-hook.sh"
CERT_PATH="/etc/letsencrypt/live/$MINIO_DOMAIN"
LE_DEPLOY_HOOK="/etc/letsencrypt/renewal-hooks/deploy/minio-cert-deploy.sh"

print_header "Validating MinIO Certificate Deployment"

# Check if domain is registered with certbot
echo "Checking if certificate exists for $MINIO_DOMAIN..."
sudo certbot certificates | grep -q "$MINIO_DOMAIN"
check_status $? "Certificate for $MINIO_DOMAIN exists" "No certificate found for $MINIO_DOMAIN"

# Check deploy hook locations
echo "Checking deploy hook..."
if [ -f "$LOCAL_DEPLOY_HOOK" ]; then
  DEPLOY_HOOK="$LOCAL_DEPLOY_HOOK"
  check_status 0 "Deploy hook script exists at $DEPLOY_HOOK" ""
elif [ -f "$LE_DEPLOY_HOOK" ]; then
  DEPLOY_HOOK="$LE_DEPLOY_HOOK"
  check_status 0 "Deploy hook script exists at $DEPLOY_HOOK" ""
else
  check_status 1 "" "Deploy hook script not found at either $LOCAL_DEPLOY_HOOK or $LE_DEPLOY_HOOK"
  exit 1
fi

# Check if hook is executable
if [ -x "$DEPLOY_HOOK" ]; then
  check_status 0 "Deploy hook is executable" ""
else
  check_status 1 "" "Deploy hook is not executable. Run: sudo chmod +x $DEPLOY_HOOK"
fi

# Check if hook references the correct domain
grep -q "$MINIO_DOMAIN" "$DEPLOY_HOOK"
check_status $? "Deploy hook contains the correct domain" "Deploy hook doesn't reference $MINIO_DOMAIN"

# Check if hook restarts the correct service
grep -q "docker compose restart minio" "$DEPLOY_HOOK"
check_status $? "Deploy hook restarts MinIO service" "Deploy hook missing restart command"

# Check Let's Encrypt symlink if using local hook
if [ "$DEPLOY_HOOK" = "$LOCAL_DEPLOY_HOOK" ]; then
  echo "Checking Let's Encrypt symlink..."
  if [ -L "$LE_DEPLOY_HOOK" ]; then
    TARGET=$(readlink "$LE_DEPLOY_HOOK")
    if [ "$TARGET" = "$LOCAL_DEPLOY_HOOK" ]; then
      check_status 0 "Let's Encrypt symlink correctly points to local hook" ""
    else
      check_status 1 "" "Let's Encrypt symlink points to $TARGET instead of $LOCAL_DEPLOY_HOOK"
    fi
  else
    check_status 1 "" "Let's Encrypt symlink not found at $LE_DEPLOY_HOOK"
  fi
fi

# Check crontab for correct deploy hook
echo "Checking crontab..."
CRONTAB=$(sudo crontab -l 2>/dev/null)
echo "$CRONTAB" | grep -q "$MINIO_DOMAIN"
check_status $? "Crontab entry found for $MINIO_DOMAIN" "No crontab entry found for $MINIO_DOMAIN"

# Check if crontab has deploy hook specified
if [ "$CRONTAB" ]; then
  echo "Checking if deploy hook is correctly specified in crontab..."
  echo "$CRONTAB" | grep "$MINIO_DOMAIN" | grep -q "\-\-deploy-hook"
  check_status $? "Deploy hook is correctly specified in crontab" "Deploy hook not specified in crontab entry"
fi

# If domain exists, check certificate expiry
if sudo certbot certificates | grep -q "$MINIO_DOMAIN"; then
  echo "Checking certificate expiry..."
  if [ -f "$CERT_PATH/fullchain.pem" ]; then
    EXPIRY_DATE=$(sudo openssl x509 -enddate -noout -in "$CERT_PATH/fullchain.pem" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_UNTIL_EXPIRY -gt 30 ]; then
      check_status 0 "Certificate valid for $DAYS_UNTIL_EXPIRY days" ""
    else
      check_status 2 "" "Certificate expires in $DAYS_UNTIL_EXPIRY days (renewal needed soon)"
    fi
  else
    check_status 1 "" "Certificate files not found in $CERT_PATH"
  fi
fi

# Check MinIO certificate directories
echo "Checking certificate deployment paths..."
if [ -d "$CERTS_DIR" ]; then
  check_status 0 "Certs directory exists at $CERTS_DIR" ""
  
  # Check certificate files
  if [ -f "$CERTS_DIR/private.key" ] && [ -f "$CERTS_DIR/public.crt" ]; then
    check_status 0 "Certificate files found in certs directory" ""
  else
    check_status 1 "" "Certificate files missing from certs directory"
  fi
else
  check_status 1 "" "Certs directory not found at $CERTS_DIR"
fi

# Check scripts directory and log file
if [ -d "$SCRIPTS_DIR" ]; then
  check_status 0 "Scripts directory exists at $SCRIPTS_DIR" ""
else
  check_status 1 "" "Scripts directory not found at $SCRIPTS_DIR"
fi

# Check for log file (it may not exist yet if no renewal has happened)
LOG_FILE="$MINIO_BASE_DIR/certificate-renewal.log"
if [ -f "$LOG_FILE" ]; then
  check_status 0 "Certificate renewal log exists at $LOG_FILE" ""
fi

# Ask about running renewal tests
read -p "Run renewal tests (takes longer)? (y/N): " RUN_TESTS
if [[ "$RUN_TESTS" =~ ^[Yy]$ ]]; then
  print_header "Testing Certificate Renewal for $MINIO_DOMAIN"
  echo "Running a dry-run renewal test..."
  
  # Run certbot with dry-run flag
  sudo certbot renew --cert-name "$MINIO_DOMAIN" --dry-run
  check_status $? "Dry-run renewal test passed" "Dry-run renewal test failed"
  
  # Option to test deploy hook
  read -p "Test deploy hook directly? (y/N): " TEST_HOOK
  if [[ "$TEST_HOOK" =~ ^[Yy]$ ]]; then
    echo "Backing up current certificates..."
    if [ -f "$CERTS_DIR/private.key" ]; then
      cp "$CERTS_DIR/private.key" "$CERTS_DIR/private.key.bak"
    fi
    
    if [ -f "$CERTS_DIR/public.crt" ]; then
      cp "$CERTS_DIR/public.crt" "$CERTS_DIR/public.crt.bak"
    fi
    
    echo "Testing deploy hook..."
    sudo RENEWED_DOMAINS="$MINIO_DOMAIN" RENEWED_LINEAGE="$CERT_PATH" bash -x "$DEPLOY_HOOK"
    
    if [ $? -eq 0 ]; then
      check_status 0 "Deploy hook test completed successfully" ""
      
      # Check if container was restarted
      echo "Checking if MinIO container was restarted..."
      if docker ps | grep -q "minio"; then
        check_status 0 "MinIO container is running" ""
      else
        check_status 1 "" "MinIO container not found after restart"
      fi
    else
      check_status 1 "" "Deploy hook test failed"
    fi
    
    # Restore backups
    read -p "Restore certificate backups? (Y/n): " RESTORE
    if [[ ! "$RESTORE" =~ ^[Nn]$ ]]; then
      if [ -f "$CERTS_DIR/private.key.bak" ]; then
        mv "$CERTS_DIR/private.key.bak" "$CERTS_DIR/private.key"
      fi
      
      if [ -f "$CERTS_DIR/public.crt.bak" ]; then
        mv "$CERTS_DIR/public.crt.bak" "$CERTS_DIR/public.crt"
      fi
      echo "Backups restored."
    fi
  fi
fi

print_header "Validation Summary"
echo "If all checks passed, your certificate renewal automation"
echo "is correctly set up for MinIO service. The certificate for"
echo "$MINIO_DOMAIN will be automatically renewed before it expires."
echo
echo "For manual renewal, you can run:"
echo "  sudo certbot renew --cert-name ${MINIO_DOMAIN} --deploy-hook $DEPLOY_HOOK --quiet"
echo
echo "To test renewal without actually renewing (dry-run):"
echo "  sudo certbot renew --cert-name ${MINIO_DOMAIN} --deploy-hook $DEPLOY_HOOK --dry-run"
echo
echo "To force a renewal (even if not due yet):"
echo "  sudo certbot renew --cert-name ${MINIO_DOMAIN} --deploy-hook $DEPLOY_HOOK --force-renewal"
echo
echo "To test the deploy hook manually without renewal:"
echo "  sudo RENEWED_DOMAINS=\"$MINIO_DOMAIN\" RENEWED_LINEAGE=\"$CERT_PATH\" bash $DEPLOY_HOOK" 