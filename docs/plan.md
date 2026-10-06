# Amended release plan

The first release is `v0.1.0-alpha.1`, published for the user's physical
touchscreen test. Device evidence is **not** a prerequisite for this alpha.

1. Build the complete extension, device helper, installer, tests, and
   documentation using Lid Sentinel's repository structure and release flow.
2. Run the automated checks and package validation, then publish a public
   GitHub prerelease with its ZIP and SHA-256 checksum.
3. Install that release on a GNOME Shell 50 Wayland laptop and complete the
   physical checklist in [Releasing](releasing.md).
4. Fix any hardware-specific behavior found in the test. Publish a new alpha
   tag for each changed build; do not move a published tag.
5. Publish a stable release only after the physical checks pass.
