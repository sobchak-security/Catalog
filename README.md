# Catalog

> **Curated camera database for the RF Buddy iOS app.**
> Source of truth for per-model rangefinder optical data: baseline length,
> viewfinder magnification, build years, lens/shutter variants, and
> bibliographic provenance for every published value.

This repository is the upstream of the catalog that the RF Buddy app
ships with on first install and pulls updates from once per day. The
data is non-secret but the **publishing pipeline is tightly controlled**:
every released catalog snapshot is cryptographically signed by the
maintainer and verified by the app before any user-visible change.

---

## What lives here

| Path | Purpose |
|------|---------|
| `data/cameras/*.json` | One JSON file per camera model — the editable source of truth |
| `data/manifest.template.json` | Manifest skeleton; revision and hashes are filled in by CI |
| `tools/` | Validators, snapshot builder, signer (Swift CLI) |
| `.github/workflows/` | Validate-on-PR, build-sign-publish-on-tag, weekly health check |
| `docs/ARCHITECTURE.md` | Why this repo exists and how it relates to RF Buddy |
| `docs/IMPLEMENTATION_PLAN.md` | Setup, CI/CD, security hardening, and milestones |
| `docs/HANDOVER_TO_RF_BUDDY.md` | Generated at the end of milestone M9; consumed by the RF Buddy project |

---

## How updates flow to users

```mermaid
flowchart LR
  Editor[Maintainer or<br/>RF Buddy Database Manager] -->|PR| Repo[(Catalog repo)]
  Repo -->|merge to main| CI[GitHub Actions]
  CI -->|sign + tag| Release[GitHub Release<br/>catalog-v{N}]
  Release -->|jsDelivr CDN| App[RF Buddy app<br/>daily background poll]
```

1. A maintainer opens a pull request that adds or edits one or more
   `data/cameras/*.json` files.
2. CI validates schema, source citations, and uniqueness.
3. On merge to `main`, CI builds a canonical snapshot, signs the
   manifest with the project's Ed25519 key (held in an Actions secret
   inside a protected environment), and publishes a tagged GitHub
   Release.
4. The RF Buddy app's background sync engine notices the new manifest
   within ~24 hours, downloads only the changed model files, verifies
   the signature, and asks the user to apply the update.

The full design of the consumer side lives in the RF Buddy repository
at `docs/ONLINE_CATALOG_PLAN.md`.

---

## Quick links

- Editorial workflow & branch protection: [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) §3
- CI/CD pipeline reference: [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) §4
- Security model & key custody: [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) §5
- Architecture rationale: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

---

## Repository URL is configurable

Although this repository currently lives at
`https://github.com/sobchak-security/Catalog.git`, every reference to
that URL on the consumer side (the RF Buddy app + its `RFBuddyCatalogKit`
Swift package) is centralised in one configuration value
(`CATALOG_REPO_URL`, see `docs/IMPLEMENTATION_PLAN.md` §2). Migrating
to a different host or a different account is a single-line change on
the consumer plus a new CI publish from the new repo.

---

## Proprietary — all rights reserved

All contents of this repository (data, schemas, and tooling) are the
exclusive property of sobchak-security. No licence is granted to any
third party. See `LICENSE-data` and `LICENSE-code` for the full notice.

---

## Maintainership

Active maintainers are listed in `CODEOWNERS`. Write access (push to
`main`, publishing releases) requires being the repository owner
(`@sobchak-security`).
