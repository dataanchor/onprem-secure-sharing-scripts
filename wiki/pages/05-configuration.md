---
grok_wiki: true
page_id: configuration
title: Configuration
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/config/defaults.conf
---

# Configuration

`onprem-sharing-scripts/config/defaults.conf` is the single source of truth for tunable values. Modules should read values from this file instead of using inline literals.

## API endpoints

| Variable | Value (default) | Purpose |
|----------|-----------------|---------|
| `FP_API_ENDPOINT` | `https://apis.anchormydata.com/api/v2/certificates/bundle` | FenixPyre certificate bundle API for mTLS provisioning. |
| `FP_INTEGRATION_API` | `https://fenixshare.anchormydata.com/ui/v1/integrations/cmmc/setup` | FenixPyre integration registration API. |
| `API_TIMEOUT` | `30` | Request timeout in seconds. |
| `API_RETRY_COUNT` | `2` | Retry attempts for API calls. |

## JWT field names

The JWT utilities try field names in order until a value is found:

- `JWT_ORG_ID_FIELDS`: `orgId`, `org_id`, `organization_id`, `organizationId`, `sub`, `tenant_id`
- `JWT_EMAIL_FIELDS`: `https://email`, `email`, `user_email`, `userEmail`, `username`, `preferred_username`, `upn`

## Certificate parameters

| Variable | Default | Purpose |
|----------|---------|---------|
| `CERT_KEY_SIZE` | `2048` | RSA key size for mTLS CSR. |
| `CERT_VALIDITY_DAYS` | `365` | Documented validity reference (actual cert lifetime comes from the API). |
| `CERT_COUNTRY` | `US` | CSR subject country. |
| `CERT_STATE` | `State` | CSR subject state. |
| `CERT_CITY` | `City` | CSR subject city. |

## Database and Docker images

| Variable | Default | Purpose |
|----------|---------|---------|
| `DB_HOST` | `postgres` | Database hostname inside Docker Compose network. |
| `DB_NAME` | `onprem_secure_db` | PostgreSQL database name. |
| `DB_PORT` | `5432` | Published PostgreSQL port. |
| `ONPREM_DOCKER_IMAGE` | pinned GCP image digest | Connector container image. |
| `POSTGRES_DOCKER_IMAGE` | `postgres:14` | PostgreSQL container image. |

## Service ports and timing

| Variable | Default | Purpose |
|----------|---------|---------|
| `PUBLIC_PORT` | `443` | Public TLS API port. |
| `PRIVATE_PORT` | `8080` | Private mTLS API port. |
| `SERVICE_STARTUP_WAIT` | `15` | Seconds to wait after `docker compose up -d`. |
| `HEALTH_CHECK_TIMEOUT` | `10` | Health check timeout in seconds. |

## Directory names

| Variable | Default | Purpose |
|----------|---------|---------|
| `ONPREM_DIR_NAME` | `fenixpyre-onprem-secure-sharing` | Base deployment directory name. |
| `MTLS_CERTS_SUBDIR` | `certs/mtls` | mTLS certificate directory. |
| `SSL_CERTS_SUBDIR` | `certs/ssl` | Public TLS certificate directory. |
| `LOGS_SUBDIR` | `logs` | Application log directory. |
| `SCRIPTS_SUBDIR` | `scripts` | Renewal hook scripts directory. |

## Let's Encrypt

| Variable | Default | Purpose |
|----------|---------|---------|
| `USE_LETSENCRYPT` | `yes` | Default to automatic Let's Encrypt certificates. |
| `CERT_RENEWAL_HOUR` | `3` | Cron hour for renewal checks. |
| `CERT_RENEWAL_MINUTE` | `0` | Cron minute for renewal checks. |
| `CERTBOT_PACKAGE` | `certbot` | Certbot package name. |

## Tokens, domains, and validation

| Variable | Default | Purpose |
|----------|---------|---------|
| `SECURE_TOKEN_LENGTH` | `32` | Hex length for `generate_secure_token`. |
| `DEFAULT_DOMAIN` | `onprem-secure-sharing.example.com` | Default public domain prompt. |
| `MINIO_BUCKET_REGEX` | `^[a-z0-9][a-z0-9.-]*$` | Bucket name validation regex. |
| `MINIO_BUCKET_MIN_LENGTH` | `3` | Minimum bucket name length. |
| `MINIO_BUCKET_MAX_LENGTH` | `63` | Maximum bucket name length. |

## Notes

- `INTERACTIVE_MODE="no"` does **not** make the setup fully non-interactive. `input_collector.sh` and certificate prompts still call `read`.
- `MIN_DISK_SPACE_GB=10` and `MIN_MEMORY_MB=8192` define recommended system resources.

## Related pages

- [[04-onprem-orchestrator]] — how the orchestrator loads this config.
- [[06-common-utilities]] — helpers that consume config values.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/config/defaults.conf/../../onprem-sharing-scripts/config/defaults.conf)

</details>
