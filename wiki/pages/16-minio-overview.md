---
grok_wiki: true
page_id: minio-overview
title: MinIO Overview
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - setup_minio.sh
---

# MinIO Overview

`setup_minio.sh` is a self-contained, self-extracting installer for a TLS-enabled MinIO instance. Unlike the On-Prem installer, it does not share modules with the `onprem-sharing-scripts/` tree.

## Self-extracting structure

The outer installer extracts its embedded payload into `minio-setup-scripts/` relative to the current working directory, then invokes `setup_minio.sh` from the payload with `MINIO_INSTALL_DIR` set. Installer options include:

| Option | Behavior |
|--------|----------|
| `--help` | Shows installer help. |
| `--extract-only` | Extracts the payload and exits. |
| `--cleanup` | Removes the extracted directory. |
| other args | Extracts and runs the inner `setup_minio.sh` with those args. |

## Inner orchestrator

The inner `setup_minio.sh` loads `config/minio_defaults.conf`, then sources:

1. `lib/common.sh`
2. `lib/distro_manager.sh`
3. `lib/prerequisites.sh`
4. `lib/cert_provisioning.sh`
5. `minio-lib/prerequisites.sh`
6. `minio-lib/cli_utils.sh`
7. `minio-lib/tls_setup.sh`
8. `minio-lib/client_utils.sh`
9. `minio-lib/input_collector.sh`
10. `minio-lib/deployment.sh`

It initializes the distribution manager, checks sudo, parses arguments, and dispatches modes.

## Modes

| Mode | Trigger | Action |
|------|---------|--------|
| `setup` | default | Full MinIO install and configuration. |
| `cert-renewal` | `--cert-renewal` | Configures certificate renewal for an existing deployment. |
| `verify` | `-v`, `--verify` | Health, TLS, bucket, and lifecycle checks. |
| `configure-buckets` | `--configure-buckets` | Creates bucket and lifecycle rules on an existing deployment. |

## Distribution manager

`lib/distro_manager.sh` detects the Linux distribution (Debian, RedHat, SUSE, Arch families), selects the appropriate package manager, and provides distribution-specific Docker and certbot installers. It also handles firewall port openings via `ufw` or `firewalld`.

## Related pages

- [[17-minio-tls-renewal]] — Let's Encrypt and renewal automation.
- [[18-minio-buckets]] — bucket and lifecycle configuration.
- [[19-minio-modules]] — module breakdown.

<details>
<summary>Relevant source files</summary>

- [setup_minio.sh/../../setup_minio.sh)

</details>
