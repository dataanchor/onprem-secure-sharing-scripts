---
grok_wiki: true
page_id: tls-setup
title: TLS Setup
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/tls_setup.sh
---

# TLS Setup

`onprem-sharing-scripts/lib/tls_setup.sh` manages the public TLS certificate for the On-Prem Sharing Service. mTLS certificate provisioning is handled separately by `cert_provisioning.sh`.

## Let's Encrypt path

`setup_tls_certificates` reads `TLS_CHOICE` (defaulting to `USE_LETSENCRYPT` from config). If Let's Encrypt is enabled:

1. Checks `/etc/letsencrypt/live/${DOMAIN}` for an existing certificate.
2. If certbot is missing, installs it via the package manager.
3. Runs `certbot certonly --non-interactive --agree-tos --standalone -d ${DOMAIN} --register-unsafely-without-email`.
4. Copies `privkey.pem` to `certs/ssl/server.key` and `fullchain.pem` to `certs/ssl/server.crt`.

## Manual TLS path

If Let's Encrypt is disabled, the operator is instructed to place `server.crt` and `server.key` into `certs/ssl/`, then press Enter. The module validates that both files exist.

## Renewal automation

`configure_cert_renewal <domain> <cert_path> <ssl_certs_dir> <base_dir>`:

1. Creates `scripts/cert-deploy-hook.sh` in the deployment directory.
2. The deploy hook copies renewed `privkey.pem` and `fullchain.pem` into `certs/ssl/`, runs `docker compose restart onprem`, and appends an event line to `certificate-renewal.log`.
3. Adds a daily root crontab entry at 03:00:

```bash
0 3 * * * sudo /usr/bin/certbot renew --cert-name ${domain} --deploy-hook $DEPLOY_HOOK_SCRIPT --quiet
```

Existing cron entries for the same domain are removed before the new entry is added.

## Related pages

- [[09-cert-provisioning]] — mTLS certificate provisioning.
- [[20-renewal-validators]] — read-only validation of this wiring.
- [[21-security-secrets]] — certificate file handling.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/tls_setup.sh/../../onprem-sharing-scripts/lib/tls_setup.sh)

</details>
