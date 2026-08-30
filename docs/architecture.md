# Architecture

DeepSeek Harness for macOS is a small Objective-C/AppKit application built directly with the macOS SDK.

## Components

| Component | Responsibility |
| --- | --- |
| `src/DeepSeekHarness.m` | App lifecycle, Dock/menu actions, service health, browser reuse, WebKit window, preferences, diagnostics |
| `src/DeepSeekHarnessLoginHelper.m` | Silent launch of the containing app through macOS Login Items |
| `assets/DeepSeekWhale.svg` | Source whale artwork used for the app and menu bar representations |
| `tools/` | Build-time SVG renderer and ICNS writer |
| `resources/*.lproj` | English and Simplified Chinese strings |
| `scripts/install.command` | Legacy/source-checkout transactional installer using the same environment-first policy |
| `scripts/install-runtime.command` | Shared environment discovery and transactional Node.js/DSH fallback setup |
| `scripts/build-release.command` | Universal compilation, validation, DMG packaging, and checksum generation |

## Opening flow

1. A Dock or menu action reads the saved browser/in-app preference.
2. The controller checks listener identity, HTTP health, and the local availability of every plugin client asset advertised by the DSH boot manifest at `127.0.0.1:3080`.
3. A stopped owned service is started with `--no-open` and given a bounded health-check window, so only the controller presents the selected browser or in-app surface. If an owned process reports a stale plugin manifest, the controller restarts it once before presentation; external processes still require confirmation.
4. Browser mode probes supported open browsers and focuses an exact local tab when found; otherwise it opens the URL.
5. In-app mode creates or restores a single WebKit window.

## Service ownership

The app records the PID and bundle identifier for a service it started. The record, process command, listener, and HTTP response are evaluated together. This is deliberate defense against stopping an unrelated program that happens to use port 3080.

## Runtime and update flow

The runtime installer first discovers previously selected paths, the launch `PATH`, and common package/version-manager locations. It executes candidates to distinguish a working installation from a merely existing file. A working DSH at or above the tested baseline is reused without mutation. If DSH needs a fallback, a working Node.js 20+ and npm are reused; only when those are unavailable does the installer download the architecture-specific Node.js 22.21.1 archive and verify it against Node.js's published SHA-256 list.

An app-managed DSH candidate is installed into a private npm prefix, staged, and verified before it replaces an earlier managed copy. npm receives a 3–8 GB Node.js heap limit derived from physical memory so the large dependency graph does not fail at Node's lower default ceiling. The selected absolute DSH and Node paths are saved in `environment.plist`, so GUI launches do not rely on shell initialization. External files are never overwritten. The app uses the same bundled installer when no compatible DSH can be run or after the user confirms a manual npm `latest` update.

The exact default is the clean-install target and minimum reused DSH compatibility baseline tested with this controller release. Update checks are on demand, never background polling. DSH profiles, sessions, plugins, and credentials remain outside the managed runtime directory and are not replaced by runtime selection or update.

## Compatibility decisions

The existing `com.yestar.deepseek-harness` bundle identifier is retained for upgrade compatibility with pre-public builds and their saved defaults. Changing it requires an explicit preference and Login Items migration plan.
