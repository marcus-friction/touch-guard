# Releasing

Version tags trigger `.github/workflows/build.yml`. It validates and packages
the tagged source, uploads the ZIP and checksum as workflow artifacts, and
publishes the same files to a GitHub Release. A tag containing `-` is a
prerelease.

## Deliverables

```text
dist/touch-guard@marcus-friction.github.io.shell-extension.zip
dist/touch-guard@marcus-friction.github.io.shell-extension.zip.sha256
```

The asset names remain stable across releases. `install.sh` selects the newest
published release, including prereleases.

## Alpha release checklist

1. Run `make package` and verify the checksum from the `dist/` directory.
2. Inspect the ZIP contents, especially `helper.py` and the polkit policy.
3. Confirm the installer test covers the public prerelease URL.
4. Publish a new tag such as `v0.1.0-alpha.6`. Hardware evidence is not required
   for this alpha; disclose that it is unverified in the README and release
   notes.
5. Confirm that the GitHub workflow succeeds and both files appear on the
   release page.

## Physical test checklist for the alpha

Perform this on a GNOME Shell 50 Wayland laptop with a working keyboard and
touchpad. Keep the laptop on a desk.

1. Install through the public README command. Record whether `sudo` was
   needed only for setup and whether the tile appears after login.
2. With the tile off, verify touch works in GNOME Shell and an application.
3. Turn the tile on. Confirm the tile says **Touchscreen guarded**, the
   top-bar indicator appears, and touch has no effect in Shell or the app.
4. Turn it off. Confirm the indicator disappears and touch works again.
5. Turn it on, lock and unlock the screen, and repeat the touch check.
6. Disconnect/reconnect the touchscreen if the hardware supports it, then
   verify the guard returns. Check that other input devices still work.
7. Reboot while guarded. After login, verify that the tile is selected and
   touch is blocked again. Touch may work at the login screen.
8. Disable the extension and verify touch works. Re-enable it and verify the
   saved choice is applied again.
9. Uninstall and confirm touch works. Record the GNOME Shell journal if any
   step fails.

## Stable release gate

Publish a stable tag only after the physical checklist passes on the claimed
GNOME version and hardware, with any failures fixed in a new alpha. Document
the tested laptop and GNOME version in the release notes. Do not claim an
untested GNOME version.

## Publish

GNOME assigns its own internal extension version, so `metadata.json` has no
`version` field. Git tags provide release versions. For a later alpha:

```sh
git tag --annotate v0.1.0-alpha.6 --message "Touch Guard v0.1.0-alpha.6"
git push origin v0.1.0-alpha.6
```

If a release build fails, fix it and use a new tag rather than moving the
published tag. Verify the release files with:

```sh
cd dist
sha256sum --check touch-guard@marcus-friction.github.io.shell-extension.zip.sha256
```

Before any extensions.gnome.org submission, re-check its review rules and
consider the external privileged helper requirement.
