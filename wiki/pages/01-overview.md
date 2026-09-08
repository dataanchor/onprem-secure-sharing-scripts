---
grok_wiki: true
page_id: overview
title: Overview
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - readme.md
  - AGENTS.md
  - ARCHITECTURE.md
  - setup_onprem.sh
  - setup_minio.sh
  - validate_onprem_renewal.sh
  - validate_minio_renewal.sh
---

# Overview

This repository contains Bash operator scripts that deploy the FenixPyre On-Prem Secure Sharing Service (the "CMMC connector") and a companion MinIO instance onto a customer-controlled Linux VM using Docker Compose. The repository ships scripts only; application code is pulled as container images at install time.

## Scope

In scope:

- Self-extracting installers that unpack, configure, and start services.
- Docker Compose stack generation for PostgreSQL and the connector.
- mTLS certificate provisioning through the FenixPyre API.
- Public TLS certificate acquisition and renewal via Let's Encrypt.
- Read-only renewal validators.

Out of scope:

- The connector application container image (pulled from GCP Artifact Registry).
- The FenixPyre platform APIs (certificate bundle and integration registration).
- MinIO itself (official image, configured by `setup_minio.sh`).

## High-level components

| Component | Form | Responsibility |
|-----------|------|----------------|
| `setup_minio.sh` | standalone monolith | TLS MinIO container via Docker Compose; setup, renewal, verify, bucket modes. |
| `setup_onprem.sh` | generated self-extracting installer | Carries a base64 gzip tar of `onprem-sharing-scripts/` and delegates to its orchestrator. |
| `onprem-sharing-scripts/setup_onprem_new.sh` | orchestrator | Sources config and lib modules, parses arguments, runs the setup pipeline. |
| `onprem-sharing-scripts/lib/*.sh` | sourced modules | One concern each: prerequisites, JWT, certs, input, TLS, config generation, service management, integration. |
| `onprem-sharing-scripts/config/defaults.conf` | configuration | All endpoints, image tags, ports, cert params, and tool lists. |
| `validate_onprem_renewal.sh`, `validate_minio_renewal.sh` | read-only checkers | Verify certbot renewal, deploy hook, cron, and certificate expiry. |

## Runtime flow

For the On-Prem service, the installer extracts its payload, then the orchestrator:

1. Checks prerequisites (FIPS, Docker, tools, network).
2. Collects inputs (domain, MinIO endpoint/credentials, public IP).
3. Validates the JWT for admin role and extracts org ID and email.
4. Generates an RSA key and CSR, then POSTs the CSR to the FenixPyre certificate bundle API.
5. Writes `server.crt`, `ca.crt`, and `server.key` into the mTLS certificate directory.
6. Obtains a public TLS certificate from Let's Encrypt (or accepts manual placement).
7. Generates `config.yaml`, `docker-compose.yaml`, and `onprem_details.txt` with runtime secrets.
8. Starts PostgreSQL and the connector with `docker compose up -d`.
9. Performs public TLS and private mTLS health checks.
10. Registers the deployment with the FenixPyre integration API.
11. Prints a summary and removes its own extracted script directory.

MinIO follows a similar but simpler path: input collection, TLS setup, Docker Compose creation, container start, health check, bucket and lifecycle configuration, and renewal wiring.

## Related pages

- [[02-repo-map]] — file and directory layout.
- [[03-self-extracting-installer]] — how `setup_onprem.sh` unpacks and runs.
- [[16-minio-overview]] — MinIO installer structure.
- [[22-operational-notes]] — deployment modes and known drift.

<details>
<summary>Relevant source files</summary>

- [readme.md](../../readme.md)
- [AGENTS.md](../../AGENTS.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
- [setup_onprem.sh](../../setup_onprem.sh)
- [setup_minio.sh](../../setup_minio.sh)
- [validate_onprem_renewal.sh](../../validate_onprem_renewal.sh)
- [validate_minio_renewal.sh](../../validate_minio_renewal.sh)

</details>
