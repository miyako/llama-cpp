# Controller lifecycle characterization (not a cleanup fix)

Refs [#18](https://github.com/miyako/llama-cpp/issues/18). This read-only fixture preserves the bounded investigation: **an accepted native `onError` without `onResponse` has not been reproduced**. It does not repair production code, establish a queue-error policy, or prove facade-level failure.

```sh
python3 -m unittest discover -s tests -p 'test_controller_lifecycle_tools.py'
python3 scripts/test-controller-lifecycle.py --tool4d "/path/to/tool4d"
```

The runner uses Python's standard library and an explicitly selected macOS tool4d. It creates a unique retained `.build/controller-*` project, byte-copies the current production `_CLI_Controller.4dm`, and records its SHA-256 and checkout HEAD. The fixture graph is:

```text
stub _CLI (currentDirectory only)
  -> actual unchanged _CLI_Controller
     -> Schedule subclass (replaces _execute only for deterministic dispatch)
     -> real 4D.SystemWorker (native execution controls)
Probe (native callback recorder, independent of controller)
```

All fixture classes share one owning project, respecting 4D inheritance boundaries. Real, already-terminated tiny workers provide typed identities for synthetic schedules; manually invoked callbacks do **not** establish native scheduling reachability. Native controls use the real controller without the dispatch override. No released components, registry facade, production startup, models, cache mutation, server, installations, rebuilds, or network calls are involved in the local test.

## What a successful characterization means

The native matrix runs `/usr/bin/true`, `/usr/bin/false`, a shell **self-only** TERM attempt, `/bin/sleep 2` with a 0.1-second worker timeout, and a deliberately nonexistent executable. Each accepted command has a three-second wait and targeted worker termination if still running. The signal attempt is recorded exactly as observed; an engine-reported exit 0 is **not** evidence of a signalled native exit. The four accepted controls currently emit `response -> termination`, not native `onError`. False must exit 1. The missing executable must return null without callbacks and synchronously report POSX2; it is not an accepted-worker runtime failure.

The 21 deterministic/native-controller checks are separated by `kind`:

| Kind | Evidence |
| --- | --- |
| `regression` | A response dispatches B before A termination; A termination while B is incomplete preserves B and its wrapper handlers; final release restores public handlers; callback counts/order/receivers/worker arguments/context; later reuse; explicit command abort; actual success/nonzero/timeout queues drain and allow a distinct later worker |
| `candidate` | Synthetic error-without-response retains incomplete A, pending parallel queues and strands a later execute; explicit abort retains message/context queues; synthetic A termination delayed until after B response clears B; directly replayed duplicate termination forwards twice |

Candidate checks intentionally assert the **current observed gap**, not desired corrected behavior. Green means those observations still characterize the unchanged source; it does not mean cleanup is fixed. A changed native sequence, missing candidate, failed invariant or altered source behavior requires investigation and updating the characterization deliberately—not silently accepting a new shape. This workflow is diagnostic, not designated a required cleanup-fix gate.

A completed run emits `summary.json` with `recoveryFixed:false` and `acceptedNativeErrorWithoutResponseReproduced:false`. No success summary is written until all strict gates pass.

The [4D 20](https://developer.4d.com/docs/20/API/SystemWorkerClass) and [21 R4](https://developer.4d.com/docs/21-R4/API/SystemWorkerClass) contracts specify optional `onError` with no response, followed by termination, and distinguish constructor rejection. Source advances on response regardless of exit code; explicit `terminate()` aborts pending commands. No established contract chooses abort versus continue for native runtime error. Any eventual fix needs that decision and identity-aware cleanup: an old worker's termination must not release a newer worker.

Reference workers 20.0.19 (`d58fcbd64eb050fcba658bf576ba18f24c51fad4`) creates a new `_server`/controller when its stored native worker is terminated. Direct controller retention therefore does not prove a public facade restart failure. Production `latest` dependency declarations are unresolved here; the reference source is not proof of installed artifact behavior.

## Strict evidence and validation tiers

`Compile project` runs first using the existing small compiler driver, with no component inputs. Success requires `success:true`, an empty diagnostics array (warnings also stop this harness), and exit 0. Both subsequent methods must execute in compiled mode and finish with fresh complete reports, every exact check ID once, no unexpected engine-error artifact, and exit 0. A green report followed by a shutdown crash fails; exit 0 without a fresh report fails. The runner retains invocation arrays, compiler diagnostics, engine version, raw stdout/stderr, exit/timeout records, per-check checkpoints, native events and the expected rejection diagnostic. Each runtime invocation is capped at 30 seconds; compilation at 120 seconds. Python gate tests exercise stale/missing reports, nonzero exits, timeouts, interpreted fallback, incomplete/duplicate assertions and unexpected native error sequences.

Local validation uses **21 R4 build 21R4.100208**. The dedicated read-only `Controller lifecycle characterization` Actions workflow uses the existing integrity workflow's official macOS arm64 **20.8 archive pinned by SHA-256**, verifies code signing, then runs this fixture without dependencies. It has only `contents:read`, uploads diagnostic artifacts even on failure, and never invokes publication. Hosted results are separate evidence and must be read from the actual run; a local 21 R4 pass is not a hosted 20.8 pass.

Exact 20.7, Windows 4D, actual accepted native error-without-response, facade scheduling, live-server readiness and inference remain unverified. Synthetic schedules, real 4D compilation, real compiled execution, and real accepted-native controls are distinct tiers. No merge or production rollout is implied by this investigation PR.
