---
grok_wiki: true
page_id: input-collection
title: Input Collection
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/input_collector.sh
---

# Input Collection

`onprem-sharing-scripts/lib/input_collector.sh` prompts the operator for values needed by the On-Prem setup. JWT token and API endpoint come from the command line; this module collects the rest.

## Domain

`collect_domain` prompts for the public domain with a default of `DEFAULT_DOMAIN` from config. It validates a simple hostname regex and stores the result in `COLLECTED_DOMAIN`.

## TLS choice

`collect_tls_cert_choice` asks whether to use Let's Encrypt for the public API. The default answer is yes. In practice, `collect_setup_inputs` uses the command-line/config value `TLS_CHOICE` instead of calling this function directly.

## MinIO configuration

`collect_minio_config` prompts for:

- MinIO endpoint (hostname, validated against a domain regex).
- MinIO root user.
- MinIO root password (minimum 8 characters, confirmed).
- MinIO bucket name (validated against `MINIO_BUCKET_REGEX`, length, no consecutive dots, not IP-like).

Values are stored in `COLLECTED_MINIO_ENDPOINT`, `COLLECTED_MINIO_ID`, `COLLECTED_MINIO_KEY`, and `COLLECTED_MINIO_BUCKET`.

## Public IP resolution

`get_ip_from_domain <domain>` uses `getent hosts` to resolve the public IP from the configured domain. If DNS resolution fails, it falls back to a manual IP prompt with IPv4 validation.

`collect_manual_ip` skips DNS and asks for the public IP directly. The `--manual-ip` flag selects this path.

## Summary and confirmation

`collect_setup_inputs` builds an array of `KEY=value` entries, prints a summary (domain, TLS choice, MinIO endpoint/bucket, public IP source), and prompts for confirmation. If the operator answers no, setup exits cleanly. Otherwise, all collected values are exported for downstream modules.

## Note

`INTERACTIVE_MODE="no"` in config does **not** eliminate interactive prompts in this module. Domain, MinIO, and IP collection still call `read`.

## Related pages

- [[04-onprem-orchestrator]] — calls `collect_setup_inputs` as part of `main_setup`.
- [[15-cli-modes]] — command-line flags that influence inputs.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/input_collector.sh/../../onprem-sharing-scripts/lib/input_collector.sh)

</details>
