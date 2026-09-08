---
grok_wiki: true
page_id: onprem-orchestrator
title: On-Prem Orchestrator
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/setup_onprem_new.sh
---

# On-Prem Orchestrator

`onprem-sharing-scripts/setup_onprem_new.sh` is the main orchestrator for the On-Prem Sharing Service setup. The self-extracting installer extracts this tree and invokes the orchestrator with `ONPREM_INSTALL_DIR` set.

## Sourcing order

The orchestrator first sources `config/defaults.conf`, then loads lib modules in dependency order:

1. `lib/common.sh`
2. `lib/prerequisites.sh`
3. `lib/jwt_utils.sh`
4. `lib/cert_provisioning.sh`
5. `lib/input_collector.sh`
6. `lib/setup_utils.sh`
7. `lib/tls_setup.sh`
8. `lib/config_generator.sh`
9. `lib/service_manager.sh`
10. `lib/integration_service.sh`
11. `lib/cli_utils.sh`
12. `lib/deployment_utils.sh`

New modules must be added to this list in dependency order.

## Directory layout

`SCRIPT_DIR` is derived from the orchestrator's location. `ONPREM_BASE_DIR` is built from `ONPREM_INSTALL_DIR` if set, otherwise from `SCRIPT_DIR`, appended with `ONPREM_DIR_NAME` from config. Subdirectories for mTLS certificates, public SSL certificates, and logs are computed from config values:

```bash
if [ -n "$ONPREM_INSTALL_DIR" ]; then
    ONPREM_BASE_DIR="$ONPREM_INSTALL_DIR/$ONPREM_DIR_NAME"
else
    ONPREM_BASE_DIR="$SCRIPT_DIR/$ONPREM_DIR_NAME"
fi
MTLS_CERTS_DIR="$ONPREM_BASE_DIR/$MTLS_CERTS_SUBDIR"
SSL_CERTS_DIR="$ONPREM_BASE_DIR/$SSL_CERTS_SUBDIR"
LOGS_DIR="$ONPREM_BASE_DIR/$LOGS_SUBDIR"
```

## main_setup pipeline

The `main_setup` function runs the full setup pipeline:

1. `check_all_prerequisites`
2. `collect_setup_inputs`
3. `setup_directories`
4. `setup_certificates` (calls `provision_certificates`)
5. `setup_tls_certificates`
6. `generate_config_files`
7. `start_services`
8. `perform_health_checks`
9. `register_integration`
10. `display_summary`

## Mode dispatch

After parsing arguments and checking sudo, the orchestrator dispatches:

| Mode | Requirement | Action |
|------|-------------|--------|
| `setup` | JWT token required | Runs `main_setup`. |
| `verify` | None | Runs `verify_deployment` against existing files. |
| `credentials` | None | Runs `extract_credentials` or recreates `onprem_details.txt` from `config.yaml`. |
| `integrate` | JWT token required | Runs `register_integration_standalone`. |

## Self-deletion

After any successful operation, the orchestrator prints an info message, changes to `/`, and runs `rm -rf "$SCRIPT_DIR"`. Anything that must survive must live under `ONPREM_BASE_DIR`, not in the extracted script directory.

## Related pages

- [[03-self-extracting-installer]] — how the outer installer unpacks and invokes this orchestrator.
- [[05-configuration]] — the config file loaded at startup.
- [[15-cli-modes]] — argument parsing and non-setup modes.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/setup_onprem_new.sh/../../onprem-sharing-scripts/setup_onprem_new.sh)

</details>
