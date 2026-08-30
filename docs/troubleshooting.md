# Troubleshooting

## macOS says the app or installer cannot be opened

Version 1.0.0 is not Apple-notarized. After dragging the app from the DMG to Applications, Control-click the installed app, choose **Open**, and confirm. If already blocked, use **System Settings → Privacy & Security → Open Anyway**. Download only from this repository's Releases page and verify the checksum.

## A new browser tab is still created

1. Confirm the existing page uses exactly `http://127.0.0.1:3080`.
2. Allow Automation access for DeepSeek Harness under **System Settings → Privacy & Security → Automation** when prompted.
3. Keep the target browser running and try again.
4. If the browser cannot expose tabs reliably, save the in-app window as the default.

Private/incognito windows, browser policies, different ports, and denied automation access can prevent tab detection.

## Harness says “Failed to load plugins”

This can happen when a plugin was updated or removed while an older DSH web process is still running with the previous loader list in memory. The controller preflights the advertised plugin assets before opening the page and automatically restarts a controller-owned stale service. For a service started by Terminal or another tool, it asks before interrupting the process. A clean restart rebuilds the loader list without deleting sessions, settings, credentials, or other plugins.

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

## DSH is not installed

Open Harness from the Dock or menu. The controller first checks whether a compatible DSH already exists and reuses it without modification. If only DSH is missing, it reuses working Node.js 20+ and npm. It downloads private Node.js only when no compatible Node/npm pair exists, all without `sudo`. Keep the Mac online only when a component must be downloaded, and leave the controller running until it reports completion.

If the setup fails, choose **Show Log** in the error dialog or reveal the runtime log at `~/Library/Logs/DeepSeek Harness/runtime-install.log`. Retrying is safe: installation is staged and the previous managed runtime is kept unless the replacement verifies successfully.

If the dialog specifically reports that Node.js ran out of memory, close memory-intensive apps and retry. The current installer automatically raises the install heap limit from 3 GB up to 8 GB according to physical memory. Logs showing a heap ceiling near 2 GB came from an older package; download the current DMG before retrying.

If a command works in Terminal but not from the Dock, rerun the one-click runtime setup. It records absolute DSH and Node paths in `~/Library/Application Support/DeepSeek Harness/environment.plist`; the app also searches common nvm, fnm, Volta, asdf, mise, nodenv, Homebrew, MacPorts, bun, and pnpm paths without sourcing shell startup files.

## A DSH update is available

Choose **Service → Check for DSH Updates…**. The controller compares the installed version with npm's official `latest` metadata and displays both versions. An update runs only after confirmation and can restart a running Harness service. Developer-preview DSH releases can change plugin or profile behavior, so keep the tested default unless you need a newer upstream fix.
