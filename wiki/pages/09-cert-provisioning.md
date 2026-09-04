---
grok_wiki: true
page_id: cert-provisioning
title: Certificate Provisioning
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/cert_provisioning.sh
---

# Certificate Provisioning

`onprem-sharing-scripts/lib/cert_provisioning.sh` generates mTLS credentials for the private API and provisions them through the FenixPyre certificate bundle API.

## CSR and key generation

`generate_mtls_csr <org_id> <email> <mtls_certs_dir> [key_size]`:

1. Creates the mTLS certificate directory.
2. Generates an RSA private key (`server.key`) using `openssl genpkey` with a fallback to `openssl genrsa`.
3. Sets the key file mode to `600`.
4. Builds a CSR config with subject fields populated from `org_id`, `email`, and cert params from config.
5. Writes `server.csr` and displays the CSR subject.
6. Removes the temporary CSR config file.

## API provisioning

`provision_mtls_certificates <jwt_token> <mtls_certs_dir> [fp_api_endpoint]`:

1. Validates the CSR exists.
2. POSTs the CSR as form-encoded data to `FP_API_ENDPOINT` with:
   - `Authorization: Bearer <jwt_token>`
   - `Content-Type: application/x-www-form-urlencoded`
   - `d-org-id`, `d-user-id`, and `d-agent-id` headers set to the extracted org ID and email.
3. Checks for HTTP status `200` or `201`; aborts on connection failure or non-2xx response.
4. Parses the JSON response with `grep`/`sed`:
   - Extracts `certificate` into `server.crt`.
   - Extracts `ca_chain` or `ca_certificate` into `ca.crt` if present.
5. Sets permissions and validates both certificates with `openssl x509`.
6. Removes the CSR file.

## Manual placement

`handle_manual_certificates <mtls_certs_dir>` supports deployments that do not use the API. The operator places `server.crt`, `server.key`, and `ca.crt` into the directory, then presses Enter. The module validates the certificates and private key, sets permissions, and prompts for organization ID and email so later steps can proceed.

## Entry point

`provision_certificates <mtls_certs_dir> [method] [jwt_token] [fp_api_endpoint]` chooses the manual or automated path. Automated provisioning validates the JWT, generates the CSR, and calls the API.

## Related pages

- [[08-jwt-gate]] — validates the JWT and extracts fields used here.
- [[11-tls-setup]] — handles public TLS separately.
- [[21-security-secrets]] — private key handling and permissions.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/cert_provisioning.sh/../../onprem-sharing-scripts/lib/cert_provisioning.sh)

</details>
