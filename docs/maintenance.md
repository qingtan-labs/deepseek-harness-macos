# Maintainer guide

## Version sources

For every app release, update these together:

- `CFBundleShortVersionString` and `CFBundleVersion` in `src/DeepSeekHarness-Info.plist`
- `APP_VERSION`, `NODE_VERSION`, and `DSH_VERSION` in `scripts/install.command`
- `RELEASE_NAME` in `scripts/build-release.command`
- `version`, runtime, DSH, and signing fields in `manifest.json`
- README download links, compatibility table, changelog, and release notes

Keep the DSH dependency pinned. Review upstream behavior and installation safety before changing it. Node.js upgrades must use a published release whose `SHASUMS256.txt` includes both target Mac archives.

## Regression matrix

Test at least these paths before release:

| Area | Checks |
| --- | --- |
| Architecture | Apple silicon build/run; Intel build/run or verified hardware test |
| Locale | English; Simplified Chinese; a third language falling back to English |
| Appearance | Light; Dark; live appearance change |
| Open preference | Browser default; in-app default; change default; one-time alternate |
| Browser reuse | Existing tab; no tab; browser closed; denied Automation; unsupported browser |
| App window | Open; close; reopen; load failure; reconnect; external link |
| Service | Stopped; healthy; starting; external Harness; unrelated port conflict |
| Startup | Login item enabled/disabled; silent login launch |
| Upgrade | Existing `/Applications` copy; existing `~/Applications` copy; fresh install |

## Repository hygiene

- Keep generated `.app`, ZIP, checksum, and `.build` content out of Git.
- Do not commit credentials, signing certificates, provisioning profiles, or notarization secrets.
- Keep English and Chinese user-visible content synchronized.
- Record user-visible changes in `CHANGELOG.md`.
- Use Issues for the roadmap and link each release to resolved Issues when practical.

## Signing roadmap

Ad-hoc signatures validate bundle consistency but do not establish a trusted developer identity. For a Gatekeeper-ready release, add Developer ID Application signing, hardened runtime where compatible, notarization, and stapling. Store credentials only in GitHub encrypted environments/secrets and require maintainer approval for a release job.

