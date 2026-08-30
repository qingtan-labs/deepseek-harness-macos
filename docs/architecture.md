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
| `scripts/install.command` | Per-user transactional installer and pinned runtime setup |
| `scripts/build-release.command` | Universal compilation, validation, packaging, and checksum generation |

## Opening flow

1. A Dock or menu action reads the saved browser/in-app preference.
2. The controller checks listener identity and HTTP health at `127.0.0.1:3080`.
3. A stopped owned service is started with `--no-open` and given a bounded health-check window, so only the controller presents the selected browser or in-app surface.
4. Browser mode probes supported open browsers and focuses an exact local tab when found; otherwise it opens the URL.
5. In-app mode creates or restores a single WebKit window.

## Service ownership

The app records the PID and bundle identifier for a service it started. The record, process command, listener, and HTTP response are evaluated together. This is deliberate defense against stopping an unrelated program that happens to use port 3080.

## Compatibility decisions

The existing `com.yestar.deepseek-harness` bundle identifier is retained for upgrade compatibility with pre-public builds and their saved defaults. Changing it requires an explicit preference and Login Items migration plan.
