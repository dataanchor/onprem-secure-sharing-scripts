---
grok_wiki: true
page_id: service-manager
title: Service Manager
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/service_manager.sh
---

# Service Manager

`onprem-sharing-scripts/lib/service_manager.sh` starts the Docker Compose stack and verifies that both the public and private APIs respond.

## Starting services

`start_services` changes into `ONPREM_BASE_DIR` and runs:

```bash
docker compose up -d
```

If the command fails, setup aborts. After startup, it waits `SERVICE_STARTUP_WAIT` seconds (default 15) for containers to initialize.

## Public health check

`perform_health_checks` first tests the public TLS endpoint:

```bash
https://${DOMAIN}/health
```

It expects HTTP `200`. Any other status, including connection failure (`FAILED`), aborts setup with `error_exit`.

## Private mTLS health check

The private API is tested at:

```bash
https://${PUBLIC_IP}:8080/health
```

The request uses the mTLS client certificate and key from `certs/mtls/server.crt` and `certs/mtls/server.key`, passes `d-user-id`, `d-agent-id`, and `d-org-id` headers, and expects HTTP `200`. A non-200 response aborts setup.

## Failure boundary

Both health checks are fatal. If either fails, the containers may already be running and must be investigated manually.

## Related pages

- [[12-config-generator]] — generates the files used here.
- [[14-integration-registration]] — runs after health checks pass.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/service_manager.sh/../../onprem-sharing-scripts/lib/service_manager.sh)

</details>
