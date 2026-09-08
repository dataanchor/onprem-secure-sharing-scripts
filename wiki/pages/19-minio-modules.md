---
grok_wiki: true
page_id: minio-modules
title: MinIO Modules
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - setup_minio.sh
---

# MinIO Modules

The MinIO installer payload inside `setup_minio.sh` is organized into shared `lib/` modules and `minio-lib/` modules specific to MinIO.

## Shared lib modules

| Module | Purpose |
|--------|---------|
| `lib/common.sh` | Print helpers, logging, package install, token generation, sudo check. |
| `lib/distro_manager.sh` | Distribution detection, package manager selection, Docker/certbot installers, firewall helpers. |
| `lib/prerequisites.sh` | FIPS, system compatibility, Docker, required tools, network checks (same logic as the On-Prem installer). |
| `lib/cert_provisioning.sh` | Shared certificate helpers, though MinIO TLS uses `minio-lib/tls_setup.sh` instead. |

## MinIO-specific modules

| Module | Purpose |
|--------|---------|
| `minio-lib/prerequisites.sh` | MinIO-specific prerequisite entry point and network checks against google.com, Docker Hub, and the Let's Encrypt ACME API. |
| `minio-lib/cli_utils.sh` | Argument parsing for `--letsencrypt`, `--manual-tls`, `--cert-renewal`, `--verify`, `--configure-buckets`, and `--skip-fips-check`. |
| `minio-lib/tls_setup.sh` | Let's Encrypt acquisition, `minio-cert-update.sh` generation, weekly cron configuration. |
| `minio-lib/client_utils.sh` | `mc` client install, alias setup, bucket and lifecycle rule creation, domain extraction from certificate. |
| `minio-lib/input_collector.sh` | Prompts for MinIO domain, root user, root password, and bucket name with validation. |
| `minio-lib/deployment.sh` | Main `setup_minio`, `verify_minio_deployment`, and `configure_minio_buckets` functions. |

## Input validation

`minio-lib/input_collector.sh` enforces:

- Domain regex validation.
- Root user minimum length of 3 and allowed character set (letters, digits, dots, hyphens, underscores).
- Root password minimum length of 14 for FIPS compliance and an allowed special-character set.
- Bucket name regex, length, and no IP-address formatting.

## Related pages

- [[16-minio-overview]] — installer orchestration.
- [[17-minio-tls-renewal]] — TLS module details.
- [[18-minio-buckets]] — bucket and lifecycle details.

<details>
<summary>Relevant source files</summary>

- [setup_minio.sh/../../setup_minio.sh)

</details>
