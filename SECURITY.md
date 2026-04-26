# Security policy

Report vulnerabilities privately via GitHub's
[Private Vulnerability Reporting](../../security/advisories/new) on
this repository.

## Out of scope

- Forks producing invalid signatures (by design; the consumer rejects
  any manifest that does not verify against a key in its allow-list).
- Public read access to release assets (catalog data is non-secret).

## In scope

- Bypass of the signing pipeline (e.g. ability to publish a release
  without going through the `production` environment).
- Compromise of an Actions secret.
- Schema or canonicalisation bugs that cause two different inputs to
  produce the same signed bytes.
