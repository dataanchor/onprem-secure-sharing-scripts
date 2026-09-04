---
grok_wiki: true
page_id: prerequisites
title: Prerequisites
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/prerequisites.sh
---

# Prerequisites

`onprem-sharing-scripts/lib/prerequisites.sh` verifies the target host before setup proceeds. It is called by the orchestrator as the first step of `main_setup`.

## Entry point

`check_all_prerequisites` runs the checks in order:

1. `check_system_compatibility`
2. `check_fips_compliance`
3. `check_docker_installation`
4. `check_required_tools`
5. `check_network_connectivity`

## System compatibility

- Confirms the OS is Linux (`OSTYPE` starts with `linux-gnu`).
- Checks available disk space (minimum 5 GB).
- Checks available memory (minimum 2 GB).
- Warnings are non-fatal; low resources are logged but setup continues.

## FIPS compliance

`check_fips_compliance` looks for FIPS mode through four methods:

- `/proc/sys/crypto/fips_enabled` equals `1`.
- `fips=1` appears in `/proc/cmdline`.
- A `fips` module is loaded (`lsmod`).
- OpenSSL version output contains `FIPS`.

If FIPS is not detected and `INTERACTIVE_MODE` is `yes`, the operator can choose to continue. If `INTERACTIVE_MODE` is `no`, setup aborts unless `--skip-fips-check` is set.

## Docker installation

`check_docker_installation` verifies that both Docker and the Docker Compose v2 plugin are available. If either is missing, it runs `install_docker`, which adds the official Docker APT repository and installs `docker-ce`, `docker-ce-cli`, and `containerd.io`. The Docker service is started and enabled automatically.

## Required tools

`check_required_tools` ensures the following are installed:

- `openssl` (required; if FIPS check is skipped, it is auto-installed)
- `curl`
- `base64`
- `grep`, `sed`, `awk`
- `tar`, `unzip`
- `jq` or `python3` (for JWT payload formatting)

Missing tools are installed via the package manager detected by `common.sh`.

## Network connectivity

`check_network_connectivity` tests reachability of `https://google.com` and `https://hub.docker.com`. Failures produce warnings but do not stop setup.

## Related pages

- [[06-common-utilities]] — helpers used by this module.
- [[08-jwt-gate]] — next step in the setup pipeline.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/prerequisites.sh/../../onprem-sharing-scripts/lib/prerequisites.sh)

</details>
