# DeepSeek Harness for macOS 1.0.3

**English** · [简体中文](https://github.com/qingtan-labs/deepseek-harness-macos/blob/v1.0.3/RELEASE-NOTES.zh-Hans.md)

This compatibility release brings the lightweight macOS controller in line with the authenticated web client shipped by official DSH 0.2.

## Fixed

- Reads and strictly validates the per-process localhost authentication URL printed by DSH 0.2 before checking or presenting the web client.
- Authenticates a reused Safari or Chromium tab once when the DSH service token changes, without opening a duplicate tab on later Dock clicks.
- Applies the same authenticated handoff to the native in-app WebKit window, including service restarts.
- Updates staged-runtime validation to follow the DSH 0.2 token handshake, retain its local cookie, and validate both absolute and relative plugin asset paths.
- Verifies the Apple silicon and Intel slices independently in the legacy/source-checkout installer.

## Updated baseline

- Fresh or recovery installations now use official `@deepseek-ai/dsh@0.2.0-rc.2`.
- A compatible existing DSH `0.2.0-rc.2` or later and Node.js `22.19.0` or later are still reused without replacement.
- The controller remains a lightweight native launcher: the complete client is provided by `dsh web`; no separate or modified web client is bundled.

Profiles, sessions, plugins, and credentials under `~/.dsh` remain outside the app bundle and are preserved during controller upgrades.

## Compatibility baseline

- macOS 13 or later; Apple silicon and Intel.
- Reusable Node.js: `22.19.0` or later.
- Private fallback Node.js: `22.21.1`.
- Tested DSH clean-install and recovery baseline: `0.2.0-rc.2`.

## Installation

Download `DeepSeek-Harness-1.0.3-macOS.dmg`, open it, and drag **DeepSeek Harness** onto **Applications**. Replace an earlier copy when prompted.

This build is ad-hoc signed and not Apple-notarized. Control-click the installed app and choose **Open**, or use **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Integrity

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.3-macOS.dmg.sha256
```

This is an independent community project and is not affiliated with DeepSeek.
