# Release plan and status

The first release was `v0.1.0-alpha.1`; `v0.1.0-alpha.2` fixes a helper error
retry loop. `v0.1.0-alpha.3` also handles event-number reuse after reconnects
and `v0.1.0-alpha.4` moves CI to a dedicated do-dev runner. Its release job
needed the GitHub CLI, so `v0.1.0-alpha.5` completed that workflow. After the
first tester reported successful installation and core touchscreen operation,
the project was promoted to stable `v1.0.0`.

1. Build the complete extension, device helper, installer, tests, and
   documentation using Lid Sentinel's repository structure and release flow.
2. Run the automated checks and package validation, then publish a public
   GitHub prerelease with its ZIP and SHA-256 checksum.
3. Install the alpha on a laptop and collect core touchscreen behavior. This
   was reported successful; detailed lock, reconnect, and reboot results were
   not reported.
4. Publish `v1.0.0` from the do-dev CI workflow. Record its ZIP and checksum
   as the stable installer target.
5. Keep the broader [hardware checklist](releasing.md) available for later
   reports and fixes; use new tags rather than moving published ones.
