# DeepSeek Harness for macOS 1.0.2

This reliability release prevents an incompatible DSH or Node.js update from replacing a working managed runtime.

## Fixed

- Enforces the full reusable Node.js minimum of `22.19.0` instead of accepting every Node.js 20+ or 22.x build. This prevents DSH dependencies that require Node.js 22.19+ from being launched with Node.js 22.14.
- Validates a staged DSH update against the current Profile before activation. The candidate must start, return the local Harness page, and serve every advertised plugin asset.
- Keeps the current managed DSH selected when startup validation detects incompatible plugins or Profile APIs.
- Recognizes the common private DSH Node runtime path in addition to Homebrew, npm, nvm, fnm, Volta, asdf, mise, nodenv, and MacPorts locations.

## Compatibility baseline

- macOS 13 or later; Apple silicon and Intel.
- Reusable Node.js: `22.19.0` or later.
- Private fallback Node.js: `22.21.1`.
- Tested DSH clean-install and recovery baseline: `0.1.1-rc.2`.

The menu's DSH update check remains user initiated. Newer npm `latest` versions are never silently installed, and a candidate that cannot start with the current Profile is not activated.

## Installation

Download `DeepSeek-Harness-1.0.2-macOS.dmg`, open it, and drag **DeepSeek Harness** onto **Applications**. Replace an earlier copy when prompted. Preferences, the selected environment record, and `~/.dsh` data remain outside the app bundle.

This build is ad-hoc signed and not Apple-notarized. Control-click the installed app and choose **Open**, or use **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Integrity

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.2-macOS.dmg.sha256
```

This is an independent community project and is not affiliated with DeepSeek.
