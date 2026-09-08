---
grok_wiki: true
page_id: jwt-gate
title: JWT Gate
repository: onprem-secure-sharing-scripts
branch: docs/generate-wiki
ref: 24ab51f
generated_at: 2026-09-04T12:00:00Z
source_files:
  - onprem-sharing-scripts/lib/jwt_utils.sh
  - onprem-sharing-scripts/config/defaults.conf
---

# JWT Gate

`onprem-sharing-scripts/lib/jwt_utils.sh` parses and validates the FenixPyre access token. Setup aborts unless the token is well-formed, not expired, and carries an admin role.

## Decoding and field extraction

- `decode_jwt <token>` extracts the payload segment, pads base64 if necessary, and prints the decoded JSON.
- `extract_jwt_field <token> <field>` returns the string or scalar value of a field using `grep`/`sed` parsing (no `jq` dependency in this module).
- `extract_organization_id <token>` iterates over `JWT_ORG_ID_FIELDS` from config and returns the first non-empty value.
- `extract_user_email <token>` iterates over `JWT_EMAIL_FIELDS` from config and returns the first non-empty value.

## Format and expiry checks

- `validate_jwt_format <token>` requires exactly three dot-separated segments and base64url characters.
- `is_jwt_expired <token>` compares the `exp` claim against the current Unix time.
- `get_jwt_expiration <token>` converts `exp` to a human-readable date.
- `display_jwt_info <token> [show_payload]` prints extracted fields and expiration status; optionally pretty-prints the payload with `python3 -m json.tool`.

## Admin role check

`is_user_admin <token>` looks for `"role/admin"` inside the `"https://roles"` array claim in the decoded payload. If the claim is missing or does not contain the admin role, the function returns false.

## Validation entry point

`validate_and_extract_jwt <token>` performs the full gate:

1. Validates format.
2. Checks expiry and aborts if expired.
3. Confirms admin role.
4. Extracts organization ID and email.
5. If required fields are missing, prompts interactively for them.
6. Exports `JWT_ORG_ID` and `JWT_USER_EMAIL` for downstream modules.

## Related pages

- [[05-configuration]] — JWT field name fallbacks are defined there.
- [[09-cert-provisioning]] — consumes the exported org ID and email.

<details>
<summary>Relevant source files</summary>

- [onprem-sharing-scripts/lib/jwt_utils.sh/../../onprem-sharing-scripts/lib/jwt_utils.sh)
- [onprem-sharing-scripts/config/defaults.conf/../../onprem-sharing-scripts/config/defaults.conf)

</details>
