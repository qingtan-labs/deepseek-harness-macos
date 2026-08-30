# DeepSeek Harness for macOS 1.0.0

The first public release brings the Dock launcher, menu bar whale, service controller, and optional in-app window into one bilingual native macOS app.

## Highlights

- Reuses an existing Harness page or window whenever the selected browser can be inspected.
- Remembers browser or in-app mode and stops prompting on every Dock click.
- Keeps the menu bar controller alive when the in-app window closes.
- Distinguishes a stopped service with a gray hollow circle, refreshes state whenever the whale menu opens, and reserves a solid green circle for a verified healthy listener.
- Checks both the port listener and HTTP response before reporting service health.
- Protects unrelated processes on port 3080 and confirms actions for externally started services.
- Reuses a working user-installed DSH `0.1.1-rc.2` or later without replacing it.
- Reuses Node.js 20+ and npm when only DSH is missing; downloads verified private Node.js 22.21.1 only when the local runtime is missing, broken, or too old.
- Records selected absolute paths so Finder, Dock, and login launches work with Homebrew, nvm, fnm, Volta, asdf, mise, nodenv, MacPorts, bun, and pnpm environments.
- Offers one-click isolated Node.js and DSH fallback when a clean Mac has no compatible Harness runtime.
- Uses a device-adaptive 3–8 GB Node.js heap limit for the large DSH dependency install, with a specific bilingual recovery message if memory is exhausted.
- Adds **Service → Check for DSH Updates…**. It checks npm only when selected and installs a newer `latest` version only after confirmation.
- Uses `@deepseek-ai/dsh@0.1.1-rc.2` as the tested exact default while still allowing an explicit newer-version opt in.
- Prevents the managed DSH service from opening an extra browser tab and recovers stale plugin-loader manifests before presentation.
- Supports English and Simplified Chinese and follows macOS Light/Dark appearance.
- Ships as one standard DMG with a universal app for Apple silicon and Intel Macs.

## Installation

Download `DeepSeek-Harness-1.0.0-macOS.dmg` from this release, open it, and drag **DeepSeek Harness** onto **Applications**. Then Control-click the installed app and choose **Open**.

Requires macOS 13 or later. A network connection is needed only if compatible local components are missing or when an update is confirmed. Existing external DSH/Node installations and `~/.dsh` data are not modified. Managed runtime changes are staged and verified before activation.

There is no silent background updater. DSH version checks and updates are initiated by the user from the Service menu.

## Signing notice

This build is ad-hoc signed and not Apple-notarized. macOS can show an unidentified-developer warning. Use Control-click **Open** or **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Integrity

Verify the downloaded DMG with the optional checksum asset:

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.dmg.sha256
```

This is an independent community project and is not affiliated with DeepSeek.
