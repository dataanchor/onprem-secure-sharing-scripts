---
grok_wiki: true
page_id: repo-map
title: Repository Map
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - AGENTS.md
  - ARCHITECTURE.md
  - onprem-sharing-scripts/AGENTS.md
  - readme.md
---

# Repository Map

## Root-level files

| Path | Purpose |
|------|---------|
| `readme.md` | User-facing install/usage/FAQ. Some sections predate the modular refactor. |
| `AGENTS.md` | Repository-level harness guidance: purpose, invariants, development notes. |
| `ARCHITECTURE.md` | Runtime flow, system boundary, components, interfaces, failure boundaries. |
| `setup_onprem.sh` | Generated self-extracting installer. Do not hand-edit; regenerate from `onprem-sharing-scripts/`. |
| `setup_minio.sh` | Self-contained MinIO installer with embedded payload modules. |
| `validate_onprem_renewal.sh` | Validates On-Prem certbot renewal, deploy hook, cron, and expiry. |
| `validate_minio_renewal.sh` | Validates MinIO certbot renewal, deploy hook, cron, and expiry. |
| `setup_minio.sh` | Standalone monolithic MinIO installer (menu-driven). |

## Modular On-Prem installer tree

`onprem-sharing-scripts/` is the source of truth for the On-Prem Sharing Service setup. It is packed into `setup_onprem.sh` at build time.

| Path | Purpose |
|------|---------|
| `setup_onprem_new.sh` | Orchestrator: loads config, sources lib modules in order, parses args, dispatches modes. |
| `config/defaults.conf` | Central configuration: API endpoints, JWT field names, cert params, images, ports, directories. |
| `lib/common.sh` | Print helpers, logging, package manager install, `generate_secure_token`, `check_sudo`. |
| `lib/prerequisites.sh` | FIPS checks, system compatibility, Docker install, required tools, network. |
| `lib/jwt_utils.sh` | JWT decode, field extraction with fallbacks, admin-role gate, expiry check. |
| `lib/cert_provisioning.sh` | RSA key + CSR, FenixPyre certificate bundle API call, manual cert placement. |
| `lib/input_collector.sh` | Interactive prompts for domain, TLS choice, MinIO config, public IP. |
| `lib/setup_utils.sh` | Directory creation and final summary display. |
| `lib/tls_setup.sh` | Let's Encrypt certbot issuance, deploy hook, cron renewal. |
| `lib/config_generator.sh` | Writes `config.yaml`, `docker-compose.yaml`, `onprem_details.txt` with runtime secrets. |
| `lib/service_manager.sh` | `docker compose up -d`, public and mTLS private health checks. |
| `lib/integration_service.sh` | FenixPyre platform integration registration. |
| `lib/cli_utils.sh` | Argument parsing and usage display. |
| `lib/deployment_utils.sh` | Verify, credentials, and standalone integration modes. |

## Embedded MinIO payload

`setup_minio.sh` carries its own base64 gzip payload after `__PAYLOAD_START__`. The payload contains `setup_minio.sh`, `config/minio_defaults.conf`, and supporting modules under `lib/` and `minio-lib/`. These embedded modules are not separate repository files; documentation for MinIO refers to `setup_minio.sh` as the source.

## Important invariants

- `setup_onprem.sh` must not be hand-edited. Change `onprem-sharing-scripts/`, then regenerate the payload.
- The On-Prem installer deletes its own script directory after a successful run.
- Runtime secrets are generated at install time and must not be committed.

## Related pages

- [[01-overview]] — repository purpose and boundaries.
- [[03-self-extracting-installer]] — how `setup_onprem.sh` extracts its payload.
- [[04-onprem-orchestrator]] — orchestrator sourcing and pipeline.

<details>
<summary>Relevant source files</summary>

- [AGENTS.md](../../AGENTS.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
- [onprem-sharing-scripts/AGENTS.md](../../onprem-sharing-scripts/AGENTS.md)
- [readme.md](../../readme.md)

</details>
