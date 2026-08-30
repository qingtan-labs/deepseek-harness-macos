# Usage guide

[English documentation](../README.md) · [简体中文说明](../README.zh-Hans.md)

## Interface previews

These images use demonstration content and focus on the macOS controller's own interactions.

![Menu bar controller](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/menu-bar-controller.svg?v=3)

The controller menu surfaces external-service status, Open/Focus, a one-time alternate window, the saved opening method, service controls, an explicit DSH update check, silent login startup, the user guide, version information, and a controller-only quit that leaves an externally started service running.

![Existing browser tab reuse](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/browser-reuse.svg?v=3)

![In-app window](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/in-app-window.svg?v=2)

The native application automatically uses English or Simplified Chinese according to macOS language settings.

## Opening Harness

The Dock icon and menu bar whale are two controls for one running application.

- A normal Dock click uses the saved default.
- The menu's primary Open action uses the same default.
- The alternate action opens in the other mode once without changing the default.
- Choose **Default opening method** to change the saved choice at any time.

Browser mode checks supported Safari and Chromium-family browsers. If it can verify a local Harness tab, it focuses that tab. If not, it opens the local address. Browser restrictions or denied Automation permission can prevent reliable inspection; the app then offers a remembered fallback.

In-app mode maintains one WebKit window. Closing the window hides it and preserves the menu bar controller. External web links are routed out of the embedded local view.

## Service menu

The status reflects both a process listening on port 3080 and a successful HTTP health response.

- **Refresh** rechecks health.
- **Restart** or **Stop** acts directly only on a controller-owned service.
- **Check for DSH Updates…** reads npm's official `latest` metadata only when selected. It shows the current, available, and controller-tested versions, then updates only after confirmation.
- Externally started Harness services require confirmation.
- An unrelated process using port 3080 is never treated as Harness and is not terminated.
- **Copy diagnostics** provides version, state, mode, browser, address, and log location for troubleshooting.

If no compatible DSH can run, the next Open action offers one-click environment selection and repair. It first reuses an existing compatible DSH, then reuses Node.js 20+ with npm when only DSH is missing, and downloads a private Node.js runtime only as the final fallback. Updating or installing a runtime stops and restarts a controller-owned Harness service as needed. External runtimes are never overwritten; a failed managed-runtime transaction preserves the previous working managed copy.

## Login startup

Enable login startup from the menu. macOS may show the item under **System Settings → General → Login Items**. Login startup is silent: it shows the whale but does not open a Harness page.

## Language and appearance

macOS chooses English or Simplified Chinese from the application's language settings. Other languages fall back to English. Native menus and windows follow the device Light/Dark appearance; no separate theme preference is needed.
