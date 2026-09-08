---
grok_wiki: true
page_id: renewal-validators
title: Renewal Validators
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - validate_onprem_renewal.sh
  - validate_minio_renewal.sh
---

# Renewal Validators

`validate_onprem_renewal.sh` and `validate_minio_renewal.sh` are read-only scripts that verify certbot renewal automation is wired correctly.

## Common checks

Both scripts require sudo and prompt for the service domain. They then validate:

1. The domain is registered with certbot (`certbot certificates`).
2. A deploy hook script exists at either the local `scripts/cert-deploy-hook.sh` or the Let's Encrypt renewal-hooks deploy directory.
3. The deploy hook is executable.
4. The deploy hook references the correct domain.
5. The deploy hook restarts the correct service (`docker compose restart onprem` or `docker compose restart minio`).
6. The Let's Encrypt deploy hook symlink points to the local hook (when applicable).
7. A root crontab entry exists for the domain with `--deploy-hook` specified.
8. Certificate files exist in the expected deployment directory (`certs/ssl/` for On-Prem, `certs/minio/` for MinIO).
9. Certificate expiry is more than 30 days away.

## Optional renewal tests

If the operator agrees, the scripts can run:

- `certbot renew --cert-name <domain> --dry-run`
- A direct deploy hook test with `RENEWED_DOMAINS` and `RENEWED_LINEAGE` environment variables set

Before the hook test, current certificates are backed up and can be restored afterward.

## Differences between validators

| Aspect | On-Prem | MinIO |
|--------|---------|-------|
| Base directory | `onpremsharing` | `minio` |
| Cert files | `certs/ssl/server.key`, `server.crt` | `certs/minio/private.key`, `public.crt` |
| Restart command | `docker compose restart onprem` | `docker compose restart minio` |
| Deploy hook symlink | `onprem-cert-deploy.sh` | `minio-cert-deploy.sh` |

## Related pages

- [[11-tls-setup]] — On-Prem renewal wiring.
- [[17-minio-tls-renewal]] — MinIO renewal wiring.

<details>
<summary>Relevant source files</summary>

- [validate_onprem_renewal.sh/../../validate_onprem_renewal.sh)
- [validate_minio_renewal.sh/../../validate_minio_renewal.sh)

</details>
