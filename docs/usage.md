# Usage guide

[English documentation](../README.md) · [简体中文说明](../README.zh-Hans.md)

## Interface previews

These images use demonstration content and focus on the macOS controller's own interactions.

![Menu bar controller](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/menu-bar-controller.svg?v=2)

The controller menu surfaces external-service status, Open/Focus, a one-time alternate window, the saved opening method, service controls, silent login startup, the user guide, version information, and a controller-only quit that leaves an externally started service running.

![Existing browser tab reuse](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/browser-reuse.svg?v=2)

![In-app window](https://raw.githubusercontent.com/qingtan-labs/deepseek-harness-macos/main/docs/images/in-app-window.svg)

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
- Externally started Harness services require confirmation.
- An unrelated process using port 3080 is never treated as Harness and is not terminated.
- **Copy diagnostics** provides version, state, mode, browser, address, and log location for troubleshooting.

## Login startup

Enable login startup from the menu. macOS may show the item under **System Settings → General → Login Items**. Login startup is silent: it shows the whale but does not open a Harness page.

## Language and appearance

macOS chooses English or Simplified Chinese from the application's language settings. Other languages fall back to English. Native menus and windows follow the device Light/Dark appearance; no separate theme preference is needed.
