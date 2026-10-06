# Touch Guard

[![Build](https://github.com/marcus-friction/touch-guard/actions/workflows/build.yml/badge.svg)](https://github.com/marcus-friction/touch-guard/actions/workflows/build.yml)

[Download the alpha release](https://github.com/marcus-friction/touch-guard/releases/tag/v0.1.0-alpha.5)
· [Development builds](https://github.com/marcus-friction/touch-guard/actions/workflows/build.yml)

Touch Guard adds a toggle to GNOME Quick Settings. When **Touch Guard** is
selected, touchscreen input has no effect. Turning it off restores touch. The
choice is saved and reapplied after login, including after a restart.

> **Alpha release:** the package and automated tests have been checked, but
> touchscreen behavior has not yet been tested on a physical laptop. This
> release is for hardware testing; see [the test checklist](docs/releasing.md).

## What it does

- Adds a native GNOME Quick Settings tile and a top-bar indicator while touch
  is guarded.
- Guards every local input node classified by udev solely as a touchscreen.
  A combined touchscreen and keyboard/touchpad/mouse node is skipped to avoid
  blocking those controls.
- Remembers the guarded choice across logins and reboots.
- Reacquires touchscreen devices that reconnect while the tile remains on.
- Releases the guard when the tile is turned off, the extension is disabled,
  or GNOME Shell exits.

The guard uses a small root-owned helper that holds a Linux evdev exclusive
grab. It does not disconnect the hardware or change a permanent udev rule.
Touch can work at the login screen and during the short interval before the
extension starts. The top-bar indicator appears only when a device is actually
guarded; the tile reports when it is waiting for a touchscreen or encounters
an error.

## Compatibility and status

This alpha release targets GNOME Shell 50 on Linux, including Fedora
Workstation 44. Other GNOME versions are not claimed. A physical touchscreen
test is still required before a stable release.

## Install

From a terminal in your GNOME desktop session, run:

```sh
curl -fsSL https://raw.githubusercontent.com/marcus-friction/touch-guard/main/install.sh | bash
```

The installer selects the newest published release, downloads the extension
ZIP and SHA-256 checksum, verifies the download, installs the root-owned
device helper and its polkit policy with `sudo`, installs the extension for the
current user, and enables it. The administrator prompt is needed during
installation; the tile does not prompt on each use. On a first installation,
log out and back in if GNOME Shell does not discover the new extension
immediately.

To inspect the installer first:

```sh
curl -fsSLO https://raw.githubusercontent.com/marcus-friction/touch-guard/main/install.sh
less install.sh
bash install.sh
```

### Updating

Rerun the same installer command. Log out and back in once to load updated
extension code. The saved guarded choice is preserved. To install a particular
release, set `TOUCH_GUARD_VERSION`, for example:

```sh
curl -fsSLO https://raw.githubusercontent.com/marcus-friction/touch-guard/main/install.sh
TOUCH_GUARD_VERSION=v0.1.0-alpha.5 bash install.sh
```

### Manual installation

Download the ZIP and `.sha256` file from the
[release page](https://github.com/marcus-friction/touch-guard/releases/tag/v0.1.0-alpha.5),
then run in their directory:

```sh
sha256sum --check touch-guard@marcus-friction.github.io.shell-extension.zip.sha256
unzip -p touch-guard@marcus-friction.github.io.shell-extension.zip helper.py > helper.py
unzip -p touch-guard@marcus-friction.github.io.shell-extension.zip \
  org.marcusfriction.touchguard.policy > org.marcusfriction.touchguard.policy
sudo install -D -m 0755 helper.py /usr/local/libexec/touch-guard-helper
sudo install -D -m 0644 org.marcusfriction.touchguard.policy \
  /usr/share/polkit-1/actions/org.marcusfriction.touchguard.policy
gnome-extensions install --force \
  touch-guard@marcus-friction.github.io.shell-extension.zip
gnome-extensions enable touch-guard@marcus-friction.github.io
```

If the last command says the extension does not exist, log out and back in,
then run it again.

## Verify

Use the physical test steps in [Releasing](docs/releasing.md). Start with the
laptop on a desk, with a working keyboard and touchpad. Select the tile and
confirm that touch has no effect in both GNOME Shell and an application. Turn
it off and confirm touch works again. Then check lock/unlock and reboot.

If the tile says **Waiting for touchscreen**, inspect the input classification:

```sh
for device in /dev/input/event*; do
  if udevadm info --query=property --name "$device" | grep -q '^ID_INPUT_TOUCHSCREEN=1$'; then
    printf '%s\n' "$device"
  fi
done
```

For GNOME Shell logs:

```sh
journalctl --user -f -o cat /usr/bin/gnome-shell
```

## Uninstall

From a source checkout, run `./uninstall.sh`. To obtain and inspect it first:

```sh
curl -fsSLO https://raw.githubusercontent.com/marcus-friction/touch-guard/main/uninstall.sh
less uninstall.sh
bash uninstall.sh
```

This disables and removes the extension, then removes the helper and polkit
policy with `sudo`.

## Build and test

On Fedora, install the build dependencies:

```sh
sudo dnf install glib2 make nodejs python3 unzip zip
```

Then run:

```sh
make check       # installer, helper, syntax, and schema checks
make package     # validated ZIP and SHA-256 checksum in dist/
make test-shell  # headless GNOME Shell lifecycle test; needs GNOME test tools
```

See [Development](docs/development.md) for the architecture and test scope,
[Releasing](docs/releasing.md) for the hardware checklist, and the
[amended plan](docs/plan.md) for the alpha release criteria.

The extension is not submitted to extensions.gnome.org. This project requires
an external privileged helper; any future submission must be evaluated
against the current GNOME review rules and tested on every claimed version.

## License

MIT. See [LICENSE](LICENSE).
