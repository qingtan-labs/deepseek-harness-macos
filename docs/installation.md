# Installation guide

## Standard installation

1. Download the ZIP and `.sha256` file from the same GitHub Release.
2. Verify the ZIP from Terminal with `shasum -a 256 -c <checksum-file>`.
3. Extract the entire folder. Do not move `install.command` away from the app.
4. Control-click `install.command`, choose **Open**, and confirm the prompt.
5. Leave Terminal open until it prints the completed installation location.

A new installation is placed in `~/Applications/DeepSeek Harness.app`. If a valid copy already exists in `/Applications` or `~/Applications`, the installer upgrades that location. It prevents a different app with the same filename from being overwritten.

## What the installer changes

- Installs or upgrades the app bundle.
- Adds the app to the current user's Dock if it is not already present.
- Downloads the architecture-appropriate Node.js runtime and verifies its upstream SHA-256.
- Installs the pinned `@deepseek-ai/dsh` version under `~/Library/Application Support/DeepSeek Harness`.
- Registers the app with Launch Services and opens it.

The normal per-user path does not require `sudo`. The installer archives an old valid app only during the upgrade transaction and removes the temporary rollback archive after success.

## Gatekeeper

The 1.0.0 release is ad-hoc signed rather than Developer ID signed and notarized. Control-click **Open** is the preferred first-run flow. If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Uninstall

1. Quit DeepSeek Harness from the menu bar.
2. Remove `DeepSeek Harness.app` from `/Applications` or `~/Applications`.
3. Optional: remove `~/Library/Application Support/DeepSeek Harness` and `~/Library/Logs/DeepSeek Harness` if you also want to delete its private runtime and logs.

Removing support data is irreversible. Back up anything you need first.

