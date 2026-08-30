# Installation guide

## Standard DMG installation

1. Download the DMG and optional `.sha256` file from the same GitHub Release.
2. Optionally verify it with `shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.dmg.sha256`.
3. Open the DMG and drag **DeepSeek Harness** onto **Applications**.
4. Control-click the installed app, choose **Open**, and confirm the prompt.

The first normal launch adds the app to the current user's Dock and starts the shared Dock/menu bar controller. A launch performed by the Login Item remains menu-bar-only and does not open a page.

To upgrade, open the new DMG and replace the existing app in Applications. Saved opening preferences, the selected environment record, logs, and `~/.dsh` data are outside the app bundle and remain intact.

## Existing-environment-first setup

The app evaluates the current device before downloading anything:

| Existing state | Result |
| --- | --- |
| Working DSH `0.1.1-rc.2` or later | Reuse that DSH and its environment; download nothing |
| No compatible DSH; working Node.js 20+ and npm | Reuse Node/npm and install only an isolated app-managed DSH |
| DSH missing/broken/too old and Node missing/broken/too old | Install verified private Node.js 22.21.1, then isolated DSH |
| Existing app-managed environment already matches | Reuse it without reinstalling |

Discovery covers the saved absolute path, the launch `PATH`, and common Homebrew, npm, nvm, fnm, Volta, asdf, mise, nodenv, MacPorts, bun, and pnpm locations. The chosen paths are recorded under `~/Library/Application Support/DeepSeek Harness/environment.plist`, which makes Finder, Dock, and login launches independent of shell startup files.

External DSH, Node.js, and npm files are never overwritten or removed. When the app must install a fallback, it uses only `~/Library/Application Support/DeepSeek Harness`. DSH profiles, sessions, plugins, and credentials under `~/.dsh` are never replaced.

Candidate managed runtimes are staged and verified before activation. A failed transaction restores the previous managed copy. A clean DSH install can take several minutes; network operations have bounded timeouts and retries. Because DSH has a large dependency graph, npm runs with a physical-memory-aware Node.js heap limit: 3 GB on smaller Macs, scaling up to 8 GB on higher-memory devices.

The default DSH version is exact for a clean fallback so the new installation begins with the combination tested for this controller. It is also the minimum reused DSH baseline. To opt in to a newer npm `latest` version later, choose **Service → Check for DSH Updates…**, review the compatibility notice, and confirm. The app does not silently update DSH.

## Legacy script installation

Maintainers can still run `scripts/install.command` from a source checkout or legacy package. It uses the same environment-first policy, upgrades a valid existing app location transactionally, registers Launch Services, and adds the Dock shortcut. DMG installation is the supported end-user path.

## Gatekeeper

The 1.0.0 release is ad-hoc signed rather than Developer ID signed and notarized. Control-click the installed app and choose **Open** for the first launch. If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally.

## Uninstall

1. Quit DeepSeek Harness from the menu bar.
2. Remove `DeepSeek Harness.app` from `/Applications` or `~/Applications`.
3. Optional: remove `~/Library/Application Support/DeepSeek Harness` and `~/Library/Logs/DeepSeek Harness` if you also want to delete its private runtime, environment record, and logs.

Removing support data is irreversible. It does not remove user-managed Node/DSH installations. Back up anything you need first.
