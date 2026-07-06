# Releasing

Chronicle uses [release-please](https://github.com/googleapis/release-please) to
maintain the changelog and version from Conventional Commits, and a tag-triggered
workflow to build, sign, notarize, and publish.

## Flow

1. Merge Conventional-Commit PRs to `main`.
2. release-please opens/updates a "release PR" that bumps the version
   (`Sources/ChronicleCLI/ChronicleVersion.swift`, the manifest) and updates
   `CHANGELOG.md`.
3. Merge the release PR. release-please tags `vX.Y.Z`.
4. The [`Release`](../../.github/workflows/release.yml) workflow builds a universal
   binary via [`scripts/release.sh`](../../scripts/release.sh), codesigns +
   notarizes + staples via [`scripts/notarize.sh`](../../scripts/notarize.sh) (when
   Developer ID secrets are present), attaches the tarball + `SHA256SUMS`, and
   updates the Homebrew tap.

## Signing secrets (repository settings)

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID` | `Developer ID Application: …` identity for codesign. |
| `NOTARY_PROFILE` | Stored `notarytool` keychain profile name. |
| `HOMEBREW_TAP_TOKEN` | Token to push the formula to the tap. |

Without these, the workflow still produces **unsigned** artifacts (useful for forks).

## Versioning policy

Pre-1.0: minor bumps may include breaking changes. From **1.0.0** the CLI surface
and storage schema follow Semantic Versioning — breaking CLI/schema changes require
a major bump, and storage migrations remain forward-compatible.

## v1.0.0 checklist

- [ ] All roadmap phases complete; docs current.
- [ ] `make precommit` clean; CI green on `main`.
- [ ] Benchmark gate green (`scripts/bench-check.sh`) and a 24h `scripts/soak.sh` run
      reviewed for memory/CPU/fd stability.
- [ ] Permissions walkthrough verified on a clean machine.
- [ ] Notarization dry-run on a release candidate tag succeeds.
- [ ] Privacy whitepaper ([`PRIVACY.md`](../PRIVACY.md)) reviewed.
- [ ] Homebrew formula installs and `chronicle version` works from the bottle.
