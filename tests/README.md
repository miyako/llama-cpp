# Download-integrity regressions

The separate [controller lifecycle characterization](controller/README.md) preserves the terminal-event investigation and its dedicated read-only workflow; it does not change or claim to fix production cleanup.

`scripts/test-download-integrity.py` uses only Python 3.9+'s standard library and an explicitly selected installed tool4d. It copies the production `_models`/`_Model` classes into a fresh `.build/integrity-*` fixture. It never runs the demo startup, fetches models, launches llama-server, resolves moving component dependencies, or touches a shared cache. Only tiny ASCII files in the fixture's resources are changed. Each engine invocation has a 120-second limit; reports, stdout/stderr, exit status, and the last assertion checkpoint are retained.

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/test-download-integrity.py --tool4d "/path/to/tool4d" --baseline
python3 scripts/test-download-integrity.py --tool4d "/path/to/tool4d"
python3 scripts/test-download-integrity.py --tool4d "/path/to/tool4d" --compile --hash-archive "/path/to/hash.zip"
```

The baseline loads the two original classes with read-only `git show` at `19616caf06d2db4b6864a2fff444ed473d5f5b0b`. It must start the controlled worker for a 3-byte `abd` cache entry whose declared SHA-256 describes `abc`, without changing the cached content. This is an expected reproduction, not a passing integrity gate.

The current fixture asserts cached/fresh SHA-256 acceptance and rejection, wrong-size cache preservation, independent same-OID destinations, File/Folder destinations, duplicate/unknown/late/reentrant callbacks, deferred out-of-order completions, one-shot dispatch, failure latching, helper result failures, malformed provider metadata, callback receivers and argument order, and unverified legacy/offline/router behavior. It also covers startup when nothing is downloaded: an existing local `options.model` starts once, a missing model reports `onError` code 2 without launching, router configurations are left to the start method, a cached router download is not launched twice, and a `Null` event is tolerated. Transfer and worker dependencies are controlled doubles. Without `--hash-component`, hashing uses a deliberately tiny-file scalar Blob and `Generate digest` double: that run does **not** validate the streaming CLI.

`--hash-archive` verifies the released ZIP against `dependencies.lock.json` before extraction, including path/symlink checks and archive permissions. `--hash-component` accepts an already extracted development candidate instead and must not be described as a release-pin verification.

`--compile` compiles the doubles as standalone projects before packaging them into `.4dbase` dependencies, then requires actual `Compile project` success and no diagnostics for both native targets and the consuming fixture, with explicit compiled component inputs. Execution requests compiled mode and checks `Is compiled mode` rather than accepting a silent interpreted fallback. `--lsp` is a separate diagnostic check, not native compilation. A zero engine exit without a fresh report is a failure; a nonzero exit is a failure even if assertion JSON exists.

The final released-archive run passed **35 assertions in compiled mode** on tool4d **21 R4 build 21R4.100208**, with diagnostic-free fixture/component compilation and clean engine exits. The Python archive-verification suite passed five tests. The baseline separately reproduced unchanged, same-size corrupt-cache acceptance.

The optional `--lsp` check with bridge 0.3.0 reported unknown component namespaces in this fixture, despite successful explicit-component `Compile project` results; no LSP pass is claimed. A separate full-production-source compilation against reference event/workers 20.0.19, tcp 20.0.10 and the released hash produced no compiler errors and the same three pre-existing demo variable warnings as the baseline, but its engine crashed at shutdown. That is not a clean full-project build or packaging pass. Neither limitation is suppressed by the runner.

Real 4D execution with a supplied released hash component proves the tiny-file wrapper/component gate, not actual HTTP transfers, facade cross-worker scheduling, native server readiness, model loading, or inference. Those need separate controlled runtime tests. A pass on 21 R4 does not establish the declared 20.7 LTS compatibility; the exact target engine must be exercised separately.

The read-only `Download integrity` PR workflow repeats the baseline and compiled fixture on checksum-pinned 20.8 using the reviewed hash ZIP. It does not publish components or run the demo. The repository's existing publication workflow is unchanged.
