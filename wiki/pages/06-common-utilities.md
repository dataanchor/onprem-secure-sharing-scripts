---
grok_wiki: true
page_id: common-utilities
title: Common Utilities
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/common.sh
---

# Common Utilities

`onprem-sharing-scripts/lib/common.sh` provides shared helpers used across the On-Prem installer modules. It is sourced first by the orchestrator.

## Output formatting

The module defines ANSI color variables and helpers:

- `error_exit <message>` — prints a red error and exits the script.
- `print_header <title>` — prints a bold section header.
- `print_success <message>` — prints a green check mark message.
- `print_info <message>` — prints a blue info message.
- `print_warning <message>` — prints a yellow warning message.
- `print_step <num> <title> <description>` — prints a numbered step block.

## Logging

`log_action <message> [log_file]` appends a timestamped line to `setup.log` by default, or to the file passed as the second argument. The timestamp format is read from `LOG_TIMESTAMP_FORMAT` in config.

## Package manager install

- `detect_package_manager` returns `apt-get`, `yum`, `dnf`, `zypper`, `pacman`, or `unknown`.
- `install_package <package>` installs a single package using the detected package manager.
- `check_required_tool <tool> [package] [description]` checks whether a tool is installed and auto-installs it if missing.

Package manager support covers apt-get, yum, dnf, zypper, and pacman.

## Directory and file helpers

- `create_directory <path> [description]` — creates a directory with logging.
- `copy_file <source> <destination> <description>` — copies a file with sudo and logs.
- `validate_file_exists <path> <description>` — aborts if a file is missing.
- `validate_directory_exists <path> <description>` — aborts if a directory is missing.

## Token generation and sudo check

- `check_sudo` verifies the script is running as root (`EUID -eq 0`); otherwise it exits.
- `generate_secure_token [length]` returns a hex token from `openssl rand -hex`. It defaults to `SECURE_TOKEN_LENGTH` from config.

## Progress indicator

`wait_with_progress <duration> [message]` prints a countdown timer for the given number of seconds.

## Related pages

- [[04-onprem-orchestrator]] — sourcing order.
- [[07-prerequisites]] — module that relies on these helpers.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/common.sh/../../onprem-sharing-scripts/lib/common.sh)

</details>
