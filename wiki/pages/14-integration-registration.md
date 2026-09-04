---
grok_wiki: true
page_id: integration-registration
title: Integration Registration
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/integration_service.sh
  - onprem-sharing-scripts/config/defaults.conf
---

# Integration Registration

`onprem-sharing-scripts/lib/integration_service.sh` registers the deployed On-Prem service with the FenixPyre platform.

## Full-setup registration

`register_integration` is called automatically at the end of `main_setup`. It:

1. Reads `onprem_details.txt` to extract the sharing service token and HMAC secret.
2. Builds a JSON payload with:
   - `orgId` from `JWT_ORG_ID`
   - `publicUrl`: `https://${DOMAIN}`
   - `privateUrl`: `https://${PUBLIC_IP}:8080`
   - `connectorToken`
   - `clientHmacSecret`
3. POSTs to `FP_INTEGRATION_API` with `Authorization: Bearer $JWT_TOKEN` and `d-org-id` headers.

## Failure handling

During full setup, integration registration is **non-fatal**. If the API returns a non-2xx status, the script prints a warning, displays the registration details, and continues. The On-Prem service is running; the operator can register manually later.

## Standalone registration mode

The `--integrate` mode uses `register_integration_standalone` in `deployment_utils.sh`, which is **fatal** on failure. That mode reads an existing `onprem_details.txt`, validates the JWT, and posts the same payload.

## API endpoint

The integration endpoint is configured in `defaults.conf`:

```bash
FP_INTEGRATION_API="https://fenixshare.anchormydata.com/ui/v1/integrations/cmmc/setup"
```

## Related pages

- [[04-onprem-orchestrator]] — calls `register_integration` in the setup pipeline.
- [[15-cli-modes]] — describes `--integrate` standalone mode.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/integration_service.sh/../../onprem-sharing-scripts/lib/integration_service.sh)
- [onprem-sharing-scripts/config/defaults.conf/../../onprem-sharing-scripts/config/defaults.conf)

</details>
