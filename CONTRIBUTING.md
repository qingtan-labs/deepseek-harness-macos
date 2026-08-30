# Contributing

Thank you for helping improve DeepSeek Harness for macOS.

## Before you start

- Search existing Issues before opening a duplicate.
- Keep credentials, tokens, private URLs, and personal data out of Issues and logs.
- Use a private security report for vulnerabilities; see [SECURITY.md](SECURITY.md).
- Keep changes focused on macOS. A future Windows implementation will live in a separate repository.

## Development setup

Requirements: macOS 13+, Apple Command Line Tools, `zsh`, and Git.

```sh
git clone https://github.com/qingtan-labs/deepseek-harness-macos.git
cd deepseek-harness-macos
./scripts/build-release.command
```

The build writes ignored artifacts to `dist/`. It compiles the Objective-C sources with warnings enabled and validates signatures, architectures, plists, and the ZIP.

## Pull requests

1. Create a focused branch from `main`.
2. Update English and Simplified Chinese strings together when user-facing text changes.
3. Update documentation, `manifest.json`, and `CHANGELOG.md` when behavior or versions change.
4. Run `./scripts/check-repository.command` and `./scripts/build-release.command`, then test the relevant Dock, menu bar, browser, in-app, and login-startup paths.
5. Complete the pull request checklist and describe any untested path.

Use clear Objective-C names, keep subprocesses bounded by timeouts, and never terminate a process solely because it uses port 3080. Preserve the service ownership and HTTP health-check safeguards.

By contributing, you agree that your contribution is licensed under the MIT License and to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
