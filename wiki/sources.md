# Sources

Inspected repository files for this wiki. Paths are relative to the repository root.

| File | Purpose |
|------|---------|
| [readme.md](../readme.md) | User-facing install, usage, FAQ, and download instructions. |
| [AGENTS.md](../AGENTS.md) | Harness knowledge file: repository purpose, invariants, and routing. |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Runtime flow, system boundary, components, interfaces, and failure boundaries. |
| [docs/development.md](../docs/development.md) | Development environment, local run guidance, build, and validation notes. |
| [setup_onprem.sh](../setup_onprem.sh) | Generated self-extracting installer for the On-Prem Sharing Service. |
| [setup_minio.sh](../setup_minio.sh) | Self-extracting installer for TLS-enabled MinIO. |
| [validate_onprem_renewal.sh](../validate_onprem_renewal.sh) | Read-only validator for On-Prem certbot renewal automation. |
| [validate_minio_renewal.sh](../validate_minio_renewal.sh) | Read-only validator for MinIO certbot renewal automation. |
| [onprem-sharing-scripts/setup_onprem_new.sh](../onprem-sharing-scripts/setup_onprem_new.sh) | Modular orchestrator that sources config/lib and dispatches setup modes. |
| [onprem-sharing-scripts/config/defaults.conf](../onprem-sharing-scripts/config/defaults.conf) | Central tunables: API endpoints, JWT fields, cert params, images, ports. |
| [onprem-sharing-scripts/lib/common.sh](../onprem-sharing-scripts/lib/common.sh) | Shared print helpers, logging, package install, token generation, sudo check. |
| [onprem-sharing-scripts/lib/prerequisites.sh](../onprem-sharing-scripts/lib/prerequisites.sh) | FIPS, system compatibility, Docker install, required tools, network checks. |
| [onprem-sharing-scripts/lib/jwt_utils.sh](../onprem-sharing-scripts/lib/jwt_utils.sh) | JWT decode, field extraction with fallbacks, admin role check, expiry. |
| [onprem-sharing-scripts/lib/cert_provisioning.sh](../onprem-sharing-scripts/lib/cert_provisioning.sh) | RSA key + CSR generation, FenixPyre API call, manual cert placement. |
| [onprem-sharing-scripts/lib/input_collector.sh](../onprem-sharing-scripts/lib/input_collector.sh) | Interactive prompts for domain, TLS choice, MinIO config, public IP. |
| [onprem-sharing-scripts/lib/tls_setup.sh](../onprem-sharing-scripts/lib/tls_setup.sh) | Let's Encrypt certbot issuance, deploy hook, cron renewal. |
| [onprem-sharing-scripts/lib/config_generator.sh](../onprem-sharing-scripts/lib/config_generator.sh) | Generates config.yaml, docker-compose.yaml, and onprem_details.txt. |
| [onprem-sharing-scripts/lib/service_manager.sh](../onprem-sharing-scripts/lib/service_manager.sh) | Docker Compose startup, public and mTLS private health checks. |
| [onprem-sharing-scripts/lib/integration_service.sh](../onprem-sharing-scripts/lib/integration_service.sh) | Registers On-Prem deployment with the FenixPyre platform API. |
| [onprem-sharing-scripts/lib/cli_utils.sh](../onprem-sharing-scripts/lib/cli_utils.sh) | Command-line argument parsing and help display. |
| [onprem-sharing-scripts/lib/deployment_utils.sh](../onprem-sharing-scripts/lib/deployment_utils.sh) | Verify, credentials, and standalone integration registration modes. |
| [onprem-sharing-scripts/lib/setup_utils.sh](../onprem-sharing-scripts/lib/setup_utils.sh) | Directory creation and final summary display. |
