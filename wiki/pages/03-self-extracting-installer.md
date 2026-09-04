---
grok_wiki: true
page_id: self-extracting-installer
title: Self-Extracting Installer
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - setup_onprem.sh
---

# Self-Extracting Installer

`setup_onprem.sh` is a generated self-extracting installer. Everything after the `__PAYLOAD_START__` marker is a base64-encoded gzip tar of the `onprem-sharing-scripts/` tree. The regeneration tool is not committed in this repository.

## Extraction

The installer determines `ORIGINAL_DIR` from the current working directory and uses `EXTRACT_DIR="$ORIGINAL_DIR/onprem-sharing-scripts"`. It finds the payload start line with `awk`, then decodes and extracts the tar into `EXTRACT_DIR`.

```bash
PAYLOAD_LINE=$(awk '/^__PAYLOAD_START__/ {print NR + 1; exit 0; }' "$0")
tail -n +$PAYLOAD_LINE "$0" | base64 -d | tar -xzf - -C "$EXTRACT_DIR"
```

## Installer modes

The installer handles these options before delegating to the orchestrator:

| Option | Behavior |
|--------|----------|
| `--help` | Shows installer help and exits. |
| `--extract-only` | Extracts the payload and exits without running setup. |
| `--cleanup` | Removes the extracted directory if it exists. |
| `--verify` / `--credentials` | Runs the orchestrator directly against an existing deployment without keeping the extracted files. |
| other args | Extracts the payload, runs `setup_onprem_new.sh` with the same args, and cleans up on exit. |

## Delegation to the orchestrator

For normal setup, the installer:

1. Extracts the payload.
2. Sets a trap to run `cleanup` on exit.
3. Marks `setup_onprem_new.sh` executable.
4. Changes back to `ORIGINAL_DIR` so the deployment directory is created relative to where the installer was invoked.
5. Invokes the orchestrator with `ONPREM_INSTALL_DIR="$ORIGINAL_DIR"`.

If no arguments are supplied, the installer shows the orchestrator's usage help.

## Verification and credentials shortcuts

`--verify` and `--credentials` first check for an existing `onpremsharing` directory in `ORIGINAL_DIR`. If found, they extract the payload temporarily, run the requested mode, and then clean up. If the deployment directory is missing, they abort and prompt the operator to run full setup first.

## Cleanup

The `cleanup` function removes `EXTRACT_DIR` after the orchestrator finishes, regardless of success or failure. The extracted scripts are therefore not available for post-run inspection unless `--extract-only` is used.

## Related pages

- [[04-onprem-orchestrator]] — the script that runs inside the extracted payload.
- [[02-repo-map]] — where the payload source lives.

<details>
<summary>Relevant source files</summary>

- [setup_onprem.sh/../../setup_onprem.sh)

</details>
