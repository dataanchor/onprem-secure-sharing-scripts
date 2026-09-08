---
grok_wiki: true
page_id: config-generator
title: Config Generator
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/config_generator.sh
  - onprem-sharing-scripts/config/defaults.conf
---

# Config Generator

`onprem-sharing-scripts/lib/config_generator.sh` creates the runtime configuration files for the On-Prem Sharing Service.

## Secret generation

`generate_config_files` calls `generate_secure_token` to create:

- `sharing_token` (sharing service token)
- `hmac_secret`
- `db_user` (prefixed with `onprem_user_` plus a random 8-hex suffix)
- `db_pass`

All values are 32 hex characters unless noted.

## config.yaml

The generated `config.yaml` contains:

- Public and private ports
- `host_url` set to `https://${DOMAIN}`
- Database connection details
- MinIO endpoint, access key, secret key, and bucket
- mTLS certificate paths (`mtls/certs/server.crt`, `server.key`, `ca.crt`)
- Public certificate paths (`ssl/certs/server.crt`, `server.key`)
- `connector_domain` set to `JWT_ORG_ID`
- `sharing_service_token` and `hmac_secret`

If a directory named `config.yaml` exists, it is removed before the file is written.

## docker-compose.yaml

The generated compose file defines two services:

- `postgres`: `postgres:14`, with credentials from config, port `5432` published, and a `pgdata` volume.
- `onprem`: the connector image from config, ports `8080` and `443` published, depends on `postgres`, and mounts `config.yaml`, `logs/`, `certs/mtls`, and `certs/ssl`.

## onprem_details.txt

A human-readable credentials file is written with:

- Public URL (`https://${DOMAIN}`)
- Private URL (`https://${PUBLIC_IP}:8080`)
- Sharing service token
- HMAC secret
- Database credentials

## Related pages

- [[05-configuration]] — default values and image pins.
- [[13-service-manager]] — starts the services using these files.
- [[21-security-secrets]] — secret generation and storage.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/config_generator.sh/../../onprem-sharing-scripts/lib/config_generator.sh)
- [onprem-sharing-scripts/config/defaults.conf/../../onprem-sharing-scripts/config/defaults.conf)

</details>
