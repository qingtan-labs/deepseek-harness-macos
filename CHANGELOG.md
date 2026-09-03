# Changelog

All notable changes are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-09-03

### Fixed

- A stopped service now uses an explicit gray hollow indicator instead of a solid dot with a semantic text color. Opening the whale menu triggers an immediate state refresh, and stale ownership records are cleared when no listener exists.

## [1.0.0] - 2026-08-30

### Added

- Unified Dock and menu bar controller with the DeepSeek whale icon.
- Saved browser or in-app opening preference, plus a one-time alternate action.
- Existing-tab reuse for supported Safari and Chromium-family browsers.
- In-app WebKit window with connection, loading, error, and reconnect states.
- Service health checks, ownership records, port-conflict protection, and diagnostics.
- Silent macOS Login Items helper.
- English and Simplified Chinese localization.
- Automatic macOS Light/Dark appearance.
- Universal Apple silicon and Intel build for macOS 13+.
- Reproducible local release script, checksum, and a single-file DMG installation flow.
- Existing-environment-first runtime selection: reuse a compatible user DSH unchanged; otherwise reuse Node.js 20+ and npm, installing only missing private components.
- Persistent absolute-path environment selection for reliable Finder, Dock, and login launches across npm, Homebrew, nvm, fnm, Volta, asdf, mise, nodenv, MacPorts, bun, and pnpm layouts.
- One-click app-managed Node.js and DSH fallback when a clean Mac has no compatible installation.
- User-confirmed **Check for DSH Updates…** action backed by npm's official `latest` metadata, with installed/tested/available version context.
- Transactional managed-runtime replacement that verifies candidates before activation and keeps the working copy on failure.

### Fixed

- Fresh DSH dependency installation now raises Node.js's heap limit adaptively from 3 GB to 8 GB based on the Mac's physical memory, preventing npm's default ~2 GB ceiling from aborting large installs. Memory failures receive a specific bilingual retry message and still leave the previous runtime untouched.
- Upgrading the app no longer reinstalls Node.js or DSH when the user's current compatible environment already works.
- Managed DSH services start with `--no-open`, leaving all browser and in-app presentation decisions to the shared controller and preventing an extra browser tab during service startup.
- Opening Harness preflights every plugin client asset advertised by the DSH boot manifest. A controller-owned service with a stale manifest is restarted automatically before presentation; an externally started service still requires confirmation before it is interrupted.

### Distribution note

- The 1.0.0 binary is ad-hoc signed and not Apple-notarized. See the README for the safe first-open flow.

[1.0.1]: https://github.com/qingtan-labs/deepseek-harness-macos/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/qingtan-labs/deepseek-harness-macos/releases/tag/v1.0.0
