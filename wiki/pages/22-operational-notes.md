---
grok_wiki: true
page_id: operational-notes
title: Operational Notes
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - readme.md
  - docs/development.md
  - ARCHITECTURE.md
  - setup_onprem.sh
---

# Operational Notes

## Deployment modes

### On-Pem Sharing Service

| Command | Mode |
|---------|------|
| `sudo ./setup_onprem.sh <JWT>` | Full setup |
| `sudo ./setup_onprem.sh --verify` | Health checks only |
| `sudo ./setup_onprem.sh --credentials` | Display or recreate credentials |
| `sudo ./setup_onprem.sh --integrate <JWT>` | Register existing deployment |
| `./setup_onprem.sh --extract-only` | Inspect extracted scripts |
| `./setup_onprem.sh --cleanup` | Remove extracted scripts |

### MinIO

| Command | Mode |
|---------|------|
| `sudo ./setup_minio.sh` | Interactive full setup |
| `sudo ./setup_minio.sh --letsencrypt` | Force Let's Encrypt |
| `sudo ./setup_minio.sh --manual-tls` | Use manually placed certificates |
| `sudo ./setup_minio.sh --cert-renewal` | Configure renewal only |
| `sudo ./setup_minio.sh --verify` | Verify existing deployment |
| `sudo ./setup_minio.sh --configure-buckets` | Configure bucket and lifecycle rules |

## Local run and development

`docs/development.md` notes that there is no build system, dependency manifest, test suite, linter, or CI in the repository. Validation is manual on a disposable Linux VM.

`setup_onprem.sh` is a generated artifact. After editing `onprem-sharing-scripts/`, the payload must be regenerated. A manual rebuild matching the extract logic is:

```bash
tar -czf - -C onprem-sharing-scripts . | base64 > payload.b64
# replace everything after __PAYLOAD_START__ in setup_onprem.sh
```

The actual regeneration tool is not committed.

## Known drift and unknowns

- `readme.md` and `validate_onprem_renewal.sh` refer to `onpremsharing/` as the deployment directory, while the modular config uses `fenixpyre-onprem-secure-sharing/`. This drift is noted in `ARCHITECTURE.md` as an unknown.
- `readme.md` describes manually placing mTLS certificates, but the modular installer provisions them via the FenixPyre API.
- It is unclear whether MinIO and the connector are expected to run on one VM or two.
- Backward-compatibility expectations for `config.yaml` keys consumed by the connector image are not documented.

## Failure boundaries

- Public or private health check failure aborts On-Prem setup.
- Integration registration failure during full setup is non-fatal; in `--integrate` mode it is fatal.
- Certificate API non-2xx or connection failure aborts setup.
- `set -e` is active in the orchestrator and installer.

## Related pages

- [[01-overview]] — repository purpose and components.
- [[03-self-extracting-installer]] — installer extraction and cleanup.
- [[15-cli-modes]] — On-Prem CLI modes.
- [[16-minio-overview]] — MinIO modes.

<details>
<summary>Relevant source files</summary>

- [readme.md/../../readme.md)
- [docs/development.md/../../docs/development.md)
- [ARCHITECTURE.md/../../ARCHITECTURE.md)
- [setup_onprem.sh/../../setup_onprem.sh)

</details>
