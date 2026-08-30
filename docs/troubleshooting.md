# Troubleshooting

## macOS says the app or installer cannot be opened

Version 1.0.0 is not Apple-notarized. Control-click `install.command`, choose **Open**, and confirm. If already blocked, use **System Settings → Privacy & Security → Open Anyway**. Download only from this repository's Releases page and verify the checksum.

## A new browser tab is still created

1. Confirm the existing page uses exactly `http://127.0.0.1:3080`.
2. Allow Automation access for DeepSeek Harness under **System Settings → Privacy & Security → Automation** when prompted.
3. Keep the target browser running and try again.
4. If the browser cannot expose tabs reliably, save the in-app window as the default.

Private/incognito windows, browser policies, different ports, and denied automation access can prevent tab detection.

## Harness says “Failed to load plugins”

This can happen when a plugin was updated or removed while an older DSH web process is still running with the previous loader list in memory. Restart the service from the whale menu, then reload Harness. A clean restart rebuilds the loader list without deleting sessions, settings, credentials, or other plugins.

If the same plugin is still reported after a restart, copy sanitized diagnostics from the Service menu and verify that the named package still exists in the active DSH web profile. Do not delete the complete `~/.dsh` directory as a first troubleshooting step.

## The whale disappears after closing the window

Use the current release and close the in-app window with its red close button. Do not choose **Quit DeepSeek Harness** from the menu or press Command-Q. Closing the window should leave the status item running.

## Port 3080 is unavailable

Use the menu to copy diagnostics. If another application owns port 3080, stop or reconfigure that application yourself. DeepSeek Harness intentionally does not terminate an unrelated process.

Useful read-only check:

```sh
lsof -nP -iTCP:3080 -sTCP:LISTEN
```

## Harness does not become healthy

- Confirm the Mac can access the npm registry and `nodejs.org` during installation.
- Refresh status after a few seconds.
- Reveal the log from the Service menu.
- Include sanitized diagnostics and relevant log lines in a Bug report.

Do not post credentials, cookies, login codes, or complete private paths.
