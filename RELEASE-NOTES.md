# DeepSeek Harness for macOS 1.0.0

The first public release brings the Dock launcher, menu bar whale, service controller, and optional in-app window into one bilingual native macOS app.

## Highlights

- Reuses an existing Harness page or window whenever the selected browser can be inspected.
- Remembers browser or in-app mode and stops prompting on every Dock click.
- Keeps the menu bar controller alive when the in-app window closes.
- Checks both the port listener and HTTP response before reporting service health.
- Protects unrelated processes on port 3080 and confirms actions for externally started services.
- Supports English and Simplified Chinese and follows macOS Light/Dark appearance.
- Ships as one universal package for Apple silicon and Intel Macs.

## Installation

Download `DeepSeek-Harness-1.0.0-macOS.zip` and its checksum from this release. Extract the complete folder, then Control-click `install.command` and choose **Open**.

Requires macOS 13 or later and an internet connection during first installation.

## Signing notice

This build is ad-hoc signed and not Apple-notarized. macOS can show an unidentified-developer warning. Use Control-click **Open** or **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Integrity

Verify the downloaded ZIP with:

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.zip.sha256
```

This is an independent community project and is not affiliated with DeepSeek.

