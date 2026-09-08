---
grok_wiki: true
page_id: cli-modes
title: CLI Modes
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/cli_utils.sh
  - onprem-sharing-scripts/lib/deployment_utils.sh
---

# CLI Modes

Argument parsing and non-setup operational modes are split between `cli_utils.sh` and `deployment_utils.sh`.

## Argument parsing

`onprem-sharing-scripts/lib/cli_utils.sh` defines `parse_arguments` and `show_usage`.

| Option | Effect |
|--------|--------|
| `-h`, `--help` | Shows usage and exits. |
| `-v`, `--verify` | Sets `SCRIPT_MODE=verify`. |
| `-c`, `--credentials` | Sets `SCRIPT_MODE=credentials`. |
| `-i`, `--integrate` | Sets `SCRIPT_MODE=integrate`. |
| `--letsencrypt` | Sets `TLS_CHOICE=yes`. |
| `--manual-tls` | Sets `TLS_CHOICE=no`. |
| `--manual-ip` | Skips DNS resolution and prompts for public IP. |
| `--skip-fips-check` | Bypasses FIPS compliance validation. |

Any positional argument is treated as the JWT token. Multiple tokens produce an error.

## Verify mode

`verify_deployment` in `deployment_utils.sh` performs health checks only. It first tries to read `onprem_details.txt` to extract the public and private URLs. If the file is missing or incomplete, it falls back to interactive domain and IP input, then runs `perform_health_checks`.

## Credentials mode

`extract_credentials` in `deployment_utils.sh` displays `onprem_details.txt`. If the file is missing, it attempts to recreate it from `config.yaml` by reading `host_url`, `sharing_service_token`, and `hmac_secret`, then resolving or prompting for the public IP.

## Integrate mode

`register_integration_standalone` in `deployment_utils.sh` registers an existing deployment. It requires:

- An existing `onprem_details.txt`.
- A valid JWT token.

It validates the JWT, extracts org ID, and POSTs the registration payload. Failure in this mode is fatal.

## Related pages

- [[04-onprem-orchestrator]] — dispatches to these modes.
- [[13-service-manager]] — health checks used by verify mode.
- [[14-integration-registration]] — registration payload structure.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/cli_utils.sh/../../onprem-sharing-scripts/lib/cli_utils.sh)
- [onprem-sharing-scripts/lib/deployment_utils.sh/../../onprem-sharing-scripts/lib/deployment_utils.sh)

</details>
