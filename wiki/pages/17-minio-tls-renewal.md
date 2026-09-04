---
grok_wiki: true
page_id: minio-tls-renewal
title: MinIO TLS Renewal
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - setup_minio.sh
---

# MinIO TLS Renewal

MinIO TLS handling and renewal automation live in the embedded `minio-lib/tls_setup.sh` module inside `setup_minio.sh`.

## Certificate acquisition

`acquire_and_setup_minio_certificates <domain> <use_letsencrypt>`:

1. Checks `/etc/letsencrypt/live/${domain}` for an existing certificate.
2. If missing and Let's Encrypt is selected, installs certbot via the distribution manager and runs:

```bash
sudo certbot certonly --non-interactive --agree-tos --standalone -d "${domain}" --register-unsafely-without-email
```

3. Copies `privkey.pem` to `certs/minio/private.key` and `fullchain.pem` to `certs/minio/public.crt`.

If Let's Encrypt is not selected and no certificate exists, setup aborts.

## Manual TLS

When `--manual-tls` is used, setup expects `private.key` and `public.crt` to already exist in `certs/minio/` before proceeding.

## minio-cert-update.sh

`configure_minio_cert_update` creates `scripts/minio-cert-update.sh`, which:

- Logs certificate expiry dates.
- Compares modification times of Let's Encrypt files against MinIO certificate files.
- Backs up and copies new certificates when they are newer.
- Restarts the MinIO container with `docker compose restart minio`.
- Cleans up old backups, keeping the last five.

## Weekly cron

A root crontab entry runs the update script every Saturday at 03:00:

```bash
0 3 * * 6 $MINIO_BASE_DIR/scripts/minio-cert-update.sh
```

The `configure_minio_cert_renewal` function ensures `crontab` is installed and the cron service is running before adding the job.

## Renewal-only mode

`setup_cert_renewal` (triggered by `--cert-renewal`) determines the domain from the existing certificate or prompts for it, asks whether to use Let's Encrypt if not specified, and calls `acquire_and_setup_minio_certificates`.

## Related pages

- [[16-minio-overview]] — MinIO installer structure.
- [[18-minio-buckets]] — bucket configuration after TLS setup.
- [[20-renewal-validators]] — validation scripts for renewal wiring.

<details>
<summary>Relevant source files</summary>

- [setup_minio.sh/../../setup_minio.sh)

</details>
