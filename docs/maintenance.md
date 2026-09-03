# Maintainer guide

## Version sources

For every app release, update these together:

- `CFBundleShortVersionString` and `CFBundleVersion` in `src/DeepSeekHarness-Info.plist`
- `APP_VERSION` in `scripts/install.command`
- `DEFAULT_NODE_VERSION` and `DEFAULT_DSH_VERSION` in `scripts/install-runtime.command`
- `DEFAULT_MIN_NODE_MAJOR` in `scripts/install-runtime.command`
- `NodeRuntimeVersion`, `NodeMinimumMajorVersion`, and `DSHRecommendedVersion` in `src/DeepSeekHarness-Info.plist`
- `RELEASE_NAME` in `scripts/build-release.command`
- `version`, runtime, DSH, and signing fields in `manifest.json`
- README download links, compatibility table, changelog, and release notes

Keep the clean-install DSH target exact and review the minimum reusable baseline separately. Review upstream web, plugin-loader, and profile behavior before changing either. The in-app update action may install npm `latest` only after the user confirms the displayed version and compatibility notice; do not turn it into a silent background update. Node.js upgrades must use a published release whose `SHASUMS256.txt` includes both target Mac archives. Lowering or raising the reusable Node minimum requires tests with npm, direct scripts, and nvm/fnm/asdf-style shims.

## Release history policy

- Increment the semantic version and create a new tag and GitHub Release for every published iteration.
- Keep all previously published Releases, tags, notes, checksums, and downloadable assets visible as the project history.
- Never move, overwrite, or delete a published version unless the maintainer explicitly requests that exact version be changed or removed.
- Mark only the newest stable release as **Latest**, and keep `CHANGELOG.md` cumulative so users can compare every iteration.

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
| Service | Stopped; healthy; starting; installing runtime; external Harness; unrelated port conflict |
| Runtime | Compatible external DSH; old/broken external DSH; Node 20+ without DSH; Node below minimum; no environment; existing managed runtime; adaptive npm heap propagation; npm out-of-memory recovery; failed rollback; update while service runs |
| Startup | Login item enabled/disabled; silent login launch |
| Upgrade | DMG replacement in `/Applications`; existing `~/Applications` copy; legacy script upgrade; fresh install; existing user runtime and `~/.dsh` preservation |

## Repository hygiene

- Keep generated `.app`, DMG, checksum, and `.build` content out of Git.
- Do not commit credentials, signing certificates, provisioning profiles, or notarization secrets.
- Keep English and Chinese user-visible content synchronized.
- Record user-visible changes in `CHANGELOG.md`.
- Use Issues for the roadmap and link each release to resolved Issues when practical.

## Signing roadmap

Ad-hoc signatures validate bundle consistency but do not establish a trusted developer identity. For a Gatekeeper-ready release, add Developer ID Application signing, hardened runtime where compatible, notarization, and stapling. Store credentials only in GitHub encrypted environments/secrets and require maintainer approval for a release job.
