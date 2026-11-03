# Component distribution publication

The normal **Publish** workflow compiles the existing component and packages its
unchanged bundled native servers. It does not rebuild or upgrade native llama
code, alter controller policy, download models, or change the exact hash20.0.1
consumer pin. Existing tool4d configuration is retained; the actual executable
version output and checksum are recorded rather than inferring a runtime version
from the download URL.

## Trust and candidate runs

`workflow_dispatch` defaults to **publish=false**. A trusted maintainer can run
the existing workflow on a reviewed feature ref to exercise the actual compiler,
six existing signing secrets and all distribution gates, without pushing a
version, tag, or release. Candidate artifacts are private workflow artifacts,
not public releases. Pull requests run only bounded deterministic tests, with
read-only permissions and no signing credentials.

Both candidate and production use the same signing job. Only the dependent
main-branch production job receives `contents: write`, and consumes the exact
same-run candidate artifact. A dispatch with **publish=true** on main (or a normal
source-triggered main push) publishes a new normal version. Workflow-only changes
need an explicit production dispatch after merge.

## Required gates and evidence

The reviewed compiler revision and existing compile/build options are preserved.
A small local-only status export is inserted immediately after the compiler's
actual `Compile project` call. Missing/stale status, process failure, false
`success`, actual `isError` diagnostics, or unclassified diagnostics stop the job.
Explicit `isError:false` warnings are retained verbatim in `compiler-status.json`
and counted in provenance. The known external-component-metadata warnings are
nonfatal; publication does **not** mean diagnostic-free compilation or a validated
installed-consumer runtime.

Only actual expected Mach-O objects are signed: the arm64 4D library and universal
macOS server. Windows binaries and all non-code resource bytes are checked for
preservation. The server's existing shared-publisher entitlements are deliberately
preserved in `scripts/llama-server-entitlements.plist`, including its legacy broad
permissions; tightening that policy is not part of this container repair. The
library carries no entitlements. No JSON, HTML or other arbitrary resource is
signed.

The identity must be exactly one valid **Developer ID Application** private-key
identity imported from the supplied P12, for the expected team `Y69CWUC25B`.
Signing uses its fingerprint, an ephemeral keychain, and isolated `HOME` plus
`CFFIXED_USER_HOME`. P12 permissions are 0600; it is deleted after import. A
`finally` block and independent `always()` recovery remove private state. The
real user's keychain search list, default and login keychains are checked unchanged.
Receipts redact secret variants and never retain command arguments.

The DMG itself is signed with a secure timestamp. Strict all-architecture
signature/team/authority checks, an explicit notarytool **Accepted** result and
downloaded log (submission ID, submitted digest, no issues, exact container and
payload path/architecture/CDHash tickets), stapling, staple validation, and
Gatekeeper `open` assessment are mandatory. The final image is mounted read-only
at a private mountpoint, and its component inventory, compiled MX64/IX64 code,
dependency declaration, payload signatures, hardened runtime, secure timestamps,
architectures and notarized requirements are verified. The ZIP is made from those
mounted bytes and independently extracted/checked. ZIPs and raw CLIs are not
stapled or represented as app-style Gatekeeper acceptance.

`SHA256SUMS` and `provenance.json` describe final distributed bytes **after**
signing, notarization, stapling, ZIP creation and credential cleanup. The notary
submitted digest is intentionally distinct from the stapled DMG digest.

The version is resolved from both package.json and the actual latest release.
Its local version commit has only a package version change and the reviewed source
as its sole parent. No commit/tag is pushed before gates pass. Production checks
the source/run/version binding, checksums, version-commit bundle and unchanged
remote main/latest release; concurrent changes stop publication rather than
rebasing or force pushing. An atomic fast-forward main plus new tag push binds the
release to that exact version commit. Assets are uploaded to a draft, downloaded
and byte-checked before the release becomes public. Existing releases/tags are
never overwritten or deleted. Failed draft-upload validation leaves a draft for
explicit investigation; do not rerun by replacing an existing tag.

## Independent released-asset verification

Download the actual new public DMG, ZIP, SHA256SUMS, provenance and receipts.
Verify SHA256SUMS, then on macOS:

```sh
codesign --verify --strict --all-architectures llama-cpp.dmg
codesign --display --verbose=4 llama-cpp.dmg
xcrun stapler validate llama-cpp.dmg
spctl --assess --verbose=4 --type open --context context:primary-signature llama-cpp.dmg
```

Mount read-only in a fresh private mountpoint; the image and ZIP both contain
`llama-cpp.4dbase`, including `.4DZ`, `Libraries`, and native platform resources.
Check final inventories and each code slice against provenance, including
`codesign --verify --strict --all-architectures --check-notarization -R=notarized`
for the library and embedded server. Inspect explicit Accepted evidence in the
notary log separately from the container and payload results.

Local mocks, read-only CI, trusted signing candidates and independent public
release verification are distinct evidence tiers. None establishes live model
inference, exact20.7 runtime execution, or a full installed-consumer smoke test.
The signing isolation/ticket patterns were adapted from the MIT-licensed
[`miyako/hash`20.0.1](https://github.com/miyako/hash/tree/c0fc53089bea0746434585c152b4448db88512a0),
not from a moving reference or a replacement workflow for that repository.
