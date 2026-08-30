<p align="center">
  <img src="assets/DeepSeekWhale.svg" width="128" alt="DeepSeek whale">
</p>

<h1 align="center">DeepSeek Harness for macOS</h1>

<p align="center">
  One native Dock and menu bar controller for DeepSeek Harness (DSH).
</p>

<p align="center">
  <a href="https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/qingtan-labs/deepseek-harness-macos?display_name=tag"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple">
  <img alt="Apple silicon and Intel" src="https://img.shields.io/badge/Mac-Apple%20silicon%20%7C%20Intel-111111">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-0b7285"></a>
</p>

<p align="center">
  <strong>English (default)</strong> · <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest/download/DeepSeek-Harness-1.0.0-macOS.zip"><strong>Download DeepSeek Harness 1.0.0 for macOS</strong></a>
</p>

DeepSeek Harness for macOS is a community-built companion that combines the Dock launcher, menu bar controls, local service management, and an optional in-app window. Clicking the Dock icon focuses an existing Harness page or window whenever possible; it does not deliberately create another tab every time.

The controller manages only `http://127.0.0.1:3080`. It does not store, proxy, or upload your DeepSeek credentials.

> [!IMPORTANT]
> This is an independent community project, not an official DeepSeek application and not affiliated with DeepSeek. DeepSeek names, logos, and trademarks belong to their respective owners.

## Trusted project links

| Purpose | Link |
| --- | --- |
| Source code | [github.com/qingtan-labs/deepseek-harness-macos](https://github.com/qingtan-labs/deepseek-harness-macos) |
| Downloads | [GitHub Releases](https://github.com/qingtan-labs/deepseek-harness-macos/releases) |
| Help and bug reports | [GitHub Issues](https://github.com/qingtan-labs/deepseek-harness-macos/issues) |
| Security reports | [Private vulnerability reporting](https://github.com/qingtan-labs/deepseek-harness-macos/security/advisories/new) |

The project is free and open source. It will never ask you to send an API key, password, or login code through an Issue.

## Product tour

### Actual Harness workspace

![DeepSeek Harness live workspace in English](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/harness-live.en.jpg)

This is a real, privacy-safe capture of a blank Harness session. It contains no API key, conversation history, or user content. The remaining images are interaction previews made with demonstration content.

### Dock and menu bar, together (interaction preview)

![DeepSeek Harness shared Dock and menu bar controller](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/menu-bar-controller.svg?v=2)

The Dock icon and menu bar whale control the same application. The menu includes external-service status, Open/Focus, a one-time alternate window, the saved opening method, service controls, silent login startup, the user guide, version information, and an explicit controller-only quit that leaves an externally started service running.

### Focus the existing browser tab (workflow preview)

![DeepSeek Harness existing browser tab reuse](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/browser-reuse.svg)

When the selected browser permits inspection, clicking the Dock icon focuses the existing local Harness page instead of opening a duplicate.

### Optional in-app window (workflow preview)

![DeepSeek Harness native in-app window](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/in-app-window.svg)

The native WebKit window keeps one local session. Closing the window does not quit the menu bar whale or stop Harness.

## Why use it?

- **One app, two entry points.** The Dock icon and menu bar whale belong to the same process; there is no second utility to launch.
- **Reuse before opening.** Browser mode checks supported Safari and Chromium-family browsers for an existing local Harness tab. In-app mode restores the same window and web session.
- **Remember my choice.** Browser or in-app mode can be saved as the default and changed from the menu at any time.
- **Service-aware actions.** HTTP health checks, port-conflict protection, and ownership records prevent the controller from stopping unrelated processes.
- **Quiet login startup.** The macOS Login Items helper starts the menu bar controller without opening a page.
- **Native localization and appearance.** English and Simplified Chinese are included; native UI follows the Mac's Light/Dark appearance automatically.
- **Universal Mac build.** One package supports Apple silicon and Intel Macs.

## Requirements

| Requirement | Value |
| --- | --- |
| macOS | 13 Ventura or later |
| Mac | Apple silicon or Intel |
| Network | Required during first installation for Node.js and DSH |
| Local endpoint | `http://127.0.0.1:3080` |
| Bundled runtime target | Node.js `22.21.1` |
| Installed DSH package | `@deepseek-ai/dsh@0.1.1-rc.2` |

## Install

1. Download the latest ZIP from [GitHub Releases](https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest).
2. Extract the complete folder. Keep `install.command` beside `DeepSeek Harness.app`.
3. Control-click `install.command`, choose **Open**, then confirm **Open**. Follow the Terminal progress.
4. The installer places a new copy in `~/Applications`, adds it to the Dock, and opens the shared Dock/menu bar controller. An existing installation is upgraded in place.

The installer verifies the app, downloads Node.js from `nodejs.org`, validates its published SHA-256 checksum, and installs the pinned DSH package from npm. It never asks for administrator access for a normal per-user installation.

### Gatekeeper notice for 1.0.0

Version 1.0.0 is ad-hoc signed and is not Apple-notarized. macOS may therefore show an unidentified-developer warning. Use the Control-click **Open** flow above, or go to **System Settings → Privacy & Security → Open Anyway** after macOS blocks the first attempt.

Do not disable Gatekeeper globally. A future release requires an Apple Developer ID and notarization to remove this first-run warning.

### Verify the download

Download the `.sha256` file beside the ZIP, keep both files in the same directory, then run:

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.zip.sha256
```

## Everyday use

- Click the **Dock icon** to use your saved opening method.
- Click the **menu bar whale** to open Harness, use the alternate method once, change the default, inspect service status, restart/stop the service, copy diagnostics, or configure login startup.
- In **browser mode**, an existing supported local tab is focused; a tab is created only if none can be verified.
- In **in-app mode**, closing the window hides it. The menu bar whale and Harness service stay available.
- Choosing **Quit DeepSeek Harness** exits the controller. Service actions remain explicit and separate.

The first browser-reuse action can trigger a macOS Automation permission request. The permission is used only to find and focus a local `127.0.0.1:3080` tab. If a browser cannot be inspected reliably, choose the in-app window or save the offered fallback.

See [Usage](docs/usage.md), [Installation](docs/installation.md), and [Troubleshooting](docs/troubleshooting.md) for details.

## Privacy and safety

- No analytics, telemetry, advertising, or update tracker is included.
- The controller communicates with the local Harness endpoint and the installer downloads only its declared runtime dependencies.
- Diagnostics copied from the menu contain operational information. Review them before posting publicly.
- Harness authentication remains inside the local Harness page. Never paste credentials into a public Issue.

## Build from source

No Xcode project or third-party build system is required. On macOS 13+ with Command Line Tools installed:

```sh
git clone https://github.com/qingtan-labs/deepseek-harness-macos.git
cd deepseek-harness-macos
./scripts/build-release.command
```

The universal, ad-hoc-signed release and checksum are written to `dist/`. The build validates plists, signatures, architectures, and ZIP integrity. See [Architecture](docs/architecture.md), [Maintenance](docs/maintenance.md), and [Release process](docs/release-process.md).

## Contributing and support

Bug reports and feature requests are welcome through [GitHub Issues](https://github.com/qingtan-labs/deepseek-harness-macos/issues). Before contributing, read [CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md), the [Code of Conduct](CODE_OF_CONDUCT.md), and [Security Policy](SECURITY.md).

The Windows companion is planned as a separate repository so platform-specific packaging and behavior remain clear. No release date is promised yet.

## License

Source code is available under the [MIT License](LICENSE). Third-party names, logos, packages, and trademarks remain subject to their owners' terms.
