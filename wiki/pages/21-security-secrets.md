---
grok_wiki: true
page_id: security-secrets
title: Security and Secrets
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/config_generator.sh
  - onprem-sharing-scripts/lib/tls_setup.sh
  - onprem-sharing-scripts/lib/cert_provisioning.sh
  - AGENTS.md
---

# Security and Secrets

## Runtime secrets

The On-Prem installer generates the following secrets at runtime using `openssl rand -hex`:

- Database user name: `onprem_user_<random>`
- Database password
- Sharing service token
- HMAC secret

These are written to `config.yaml` and `onprem_details.txt`. They must never be committed or shared.

## mTLS and private API

The private API listens on port `8080` and requires mTLS:

- `server.crt` and `server.key` are generated during CSR creation and provisioned by the FenixPyre certificate bundle API.
- `ca.crt` is extracted from the same API response.
- The health check uses these files as the client certificate.

## Manual certificate handling

Both On-Prem and MinIO installers support manual certificate placement. Operators must place files in the expected directories before continuing. The scripts validate certificate and key integrity with OpenSSL.

## Private key permissions

- mTLS `server.key` is set to `600` after generation.
- MinIO `private.key` is copied by certbot deploy hooks and inherits ownership from the copy operation.
- Public certificates are set to `644`.

## Self-deletion

The On-Prem orchestrator removes its extracted script directory after any successful run. Operators who need to inspect the scripts must use `--extract-only` before running setup.

## Things not to commit

Per `AGENTS.md` and `docs/development.md`, do not commit:

- Certificates or keys under `certs/`
- `config.yaml`
- `onprem_details.txt`
- JWT tokens or API keys

## Related pages

- [[09-cert-provisioning]] — mTLS certificate generation.
- [[11-tls-setup]] — public TLS and renewal hook.
- [[12-config-generator]] — secret generation.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/config_generator.sh/../../onprem-sharing-scripts/lib/config_generator.sh)
- [onprem-sharing-scripts/lib/tls_setup.sh/../../onprem-sharing-scripts/lib/tls_setup.sh)
- [onprem-sharing-scripts/lib/cert_provisioning.sh/../../onprem-sharing-scripts/lib/cert_provisioning.sh)
- [AGENTS.md/../../AGENTS.md)

</details>
