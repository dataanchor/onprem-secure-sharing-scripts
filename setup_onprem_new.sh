#!/bin/bash
set -e

# OnPrem Sharing Service Setup Script - Main Orchestrator
# This is the main entry point that coordinates all setup activities

# Determine script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration file
CONFIG_FILE="$SCRIPT_DIR/config/defaults.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please ensure config/defaults.conf exists in the script directory."
    exit 1
fi

# Source all required modules
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/prerequisites.sh"
source "$SCRIPT_DIR/lib/jwt_utils.sh"
source "$SCRIPT_DIR/lib/cert_provisioning.sh"
source "$SCRIPT_DIR/lib/input_collector.sh"
source "$SCRIPT_DIR/lib/setup_utils.sh"
source "$SCRIPT_DIR/lib/tls_setup.sh"
source "$SCRIPT_DIR/lib/config_generator.sh"
source "$SCRIPT_DIR/lib/service_manager.sh"
source "$SCRIPT_DIR/lib/integration_service.sh"
source "$SCRIPT_DIR/lib/cli_utils.sh"
source "$SCRIPT_DIR/lib/deployment_utils.sh"

# Global configuration (using values from config file)
# Use ONPREM_INSTALL_DIR if set by installer, otherwise use SCRIPT_DIR
if [[ -n "$ONPREM_INSTALL_DIR" ]]; then
    ONPREM_BASE_DIR="$ONPREM_INSTALL_DIR/$ONPREM_DIR_NAME"
else
    ONPREM_BASE_DIR="$SCRIPT_DIR/$ONPREM_DIR_NAME"
fi
MTLS_CERTS_DIR="$ONPREM_BASE_DIR/$MTLS_CERTS_SUBDIR"
SSL_CERTS_DIR="$ONPREM_BASE_DIR/$SSL_CERTS_SUBDIR"
LOGS_DIR="$ONPREM_BASE_DIR/$LOGS_SUBDIR"

# Database configuration (from config file)
# DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT are loaded from config

# Function to handle certificate provisioning
setup_certificates() {
  print_step 2 "mTLS Certificate Provisioning" "Setting up mTLS certificates for secure communication"
  
  # Use the modular certificate provisioning
  provision_certificates "$MTLS_CERTS_DIR" "$CERT_METHOD" "$JWT_TOKEN" "$API_ENDPOINT"
  
  print_success "mTLS certificates provisioned successfully"
  echo "-------------------------------------------------------------"
  echo
}

# Main setup orchestration function
main_setup() {
  print_header "FenixPyre OnPrem Sharing Service Setup"
  echo "This automated setup will configure and start the OnPrem Sharing Service"
  echo "with PostgreSQL, mTLS authentication, and TLS-enabled public API."
  echo "=============================================="
  echo
  
  # Check prerequisites first
  check_all_prerequisites
  
  # Collect all required inputs
  collect_setup_inputs
  
  # Execute setup steps
  setup_directories
  setup_certificates
  setup_tls_certificates  
  generate_config_files
  start_services
  perform_health_checks
  register_integration
  display_summary
}



# Script entry point
main() {
  # Parse command line arguments first
  parse_arguments "$@"
  
  # Check if running with sudo
  check_sudo
  
  # Handle different modes
  case "$SCRIPT_MODE" in
    "setup")
      if [[ -z "$JWT_TOKEN" ]]; then
        echo "Error: JWT token is required for setup mode"
        echo
        show_usage
        exit 1
      fi
      main_setup
      ;;
    "verify")
      # Verification doesn't require JWT token as it reads from existing files
      verify_deployment
      ;;
    "credentials")
      # Credentials extraction doesn't require JWT token
      extract_credentials
      ;;
    "integrate")
      if [[ -z "$JWT_TOKEN" ]]; then
        echo "Error: JWT token is required for integration registration"
        echo
        show_usage
        exit 1
      fi
      register_integration_standalone
      ;;
    *)
      echo "Error: Invalid mode"
      show_usage
      exit 1
      ;;
  esac
  
  # Cleanup setup scripts after any successful operation
  print_info "Cleaning up setup scripts..."
  cd /
  rm -rf "$SCRIPT_DIR" || print_warning "Failed to remove setup scripts directory"
  print_success "Setup scripts cleaned up successfully"
}

# Run main function
main "$@" 