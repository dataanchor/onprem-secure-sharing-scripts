---
grok_wiki: true
page_id: minio-buckets
title: MinIO Buckets
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - setup_minio.sh
---

# MinIO Buckets

After MinIO starts, `minio-lib/deployment.sh` and `minio-lib/client_utils.sh` configure buckets and lifecycle rules for automatic cleanup.

## Default bucket configuration

`config/minio_defaults.conf` defines:

```bash
DEFAULT_BUCKET_NAME="data"
LIFECYCLE_EXPIRY_DAYS=1
LIFECYCLE_PREFIXES=("downloads" "/downloads" "tmp-files" "/tmp-files")
```

## MinIO client installation

`ensure_minio_client_ready` checks whether `mc` is available inside the running MinIO container. If not, it downloads the Linux AMD64 `mc` binary from `https://dl.min.io/client/mc/release/linux-amd64/mc` and installs it to `/usr/bin/mc`.

## Alias configuration

`mc alias set local https://${MINIO_DOMAIN} <root_user> <root_password> --insecure` is configured inside the container. Credentials are read from `minio.env` if variables are not already in scope. Legacy deployments that embedded credentials in `docker-compose.yaml` are also supported.

## Bucket creation

`setup_minio_bucket_and_lifecycle <bucket_name>`:

1. Creates the bucket if it does not already exist (`mc mb local/${bucket_name}`).
2. Adds an expiration lifecycle rule for each prefix in `LIFECYCLE_PREFIXES` with `mc ilm add --expire-days $LIFECYCLE_EXPIRY_DAYS --prefix $prefix`.

Failures to add individual lifecycle rules are logged as warnings but do not abort setup.

## Verify mode

`verify_minio_deployment` lists buckets and checks whether lifecycle rules are configured for each. It treats missing buckets as a verification failure.

## Related pages

- [[16-minio-overview]] — MinIO installer structure.
- [[17-minio-tls-renewal]] — TLS setup that precedes bucket configuration.
- [[19-minio-modules]] — input collector and client utilities.

<details>
<summary>Relevant source files</summary>

- [setup_minio.sh/../../setup_minio.sh)

</details>
