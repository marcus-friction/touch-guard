# Development

## Architecture

The installable extension lives in
`touch-guard@marcus-friction.github.io`.

- `extension.js` owns the Quick Settings tile, indicator, GSettings, and Shell
  lifecycle.
- `controller.js` starts the helper through `pkexec`, observes its status,
  and closes its stdin when guarding stops.
- `helper.py` discovers touchscreen-only evdev nodes through udev and holds
  `EVIOCGRAB` file descriptors until the extension closes stdin. It rescans
  every three seconds to handle device changes.
- `org.marcusfriction.touchguard.policy` permits the fixed root-owned helper
  to run for the active local user. It accepts no device paths or other
  commands from the extension.
- `schemas/` stores the persistent `guarded` choice. The extension reapplies
  it after login; the helper itself holds no persistent setting.
- `install.sh` installs verified release files. `uninstall.sh` removes the
  extension and privileged files.

The duplicate license inside the UUID directory is intentional: the ZIP
includes it, while the root license covers the repository.

The helper releases all device grabs when the tile is turned off, the
extension is disabled, or GNOME Shell closes its stdin pipe. Closing the
file descriptors also releases the grabs if the helper exits unexpectedly.
The `WAITING` status means the saved choice is on but no eligible touchscreen
is currently available. The top-bar indicator only shows an active grab.

## Commands

On Fedora, install `glib2 make nodejs python3 unzip zip`. Run:

```sh
make check
make package
```

For a headless GNOME Shell 50 lifecycle test, also install `gnome-shell`,
`gjs`, and its test tool, then run:

```sh
make test-shell
```

## Test scope

The installer tests cover stable and pinned release downloads, helper installation,
immediate enablement, next-login enablement, upgrade detection, and the
fallback message. Helper tests cover touchscreen selection, failed-grab
cleanup, and release on stdin EOF. The Shell smoke test covers creation,
disable, and re-enable of the Quick Settings item.

These tests cannot establish that a particular laptop's touchscreen is
correctly classified or that its touch events stop in GNOME Shell and
Wayland clients. That requires the physical checklist in
[Releasing](releasing.md).

CI package and release jobs use a repository-specific `do-dev` runner slot.
This public repository does not run untrusted pull-request code on that
self-hosted runner; the workflow triggers only on pushes to `main`, version
tags, and manual dispatches by users with repository access.

## Project provenance

The initial implementation was created with AI assistance for personal use.
Maintainers and contributors are responsible for understanding, testing, and
supporting every change. Check the current GNOME review guidelines before
any extensions.gnome.org submission.
