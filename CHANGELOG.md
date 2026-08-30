# Changelog

All notable changes are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Managed DSH services now start with `--no-open`, leaving all browser and in-app presentation decisions to the shared controller and preventing an extra browser tab during service startup.
- Opening Harness now preflights every plugin client asset advertised by the DSH boot manifest. A controller-owned service with a stale manifest is restarted automatically before presentation; an externally started service still requires confirmation before it is interrupted.

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
- Reproducible local release script, checksum, and bilingual installer.

### Distribution note

- The 1.0.0 binary is ad-hoc signed and not Apple-notarized. See the README for the safe first-open flow.

[1.0.0]: https://github.com/qingtan-labs/deepseek-harness-macos/releases/tag/v1.0.0
