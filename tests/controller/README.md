# Controller lifecycle characterization and idle launch rejection

Refs [#18](https://github.com/miyako/llama-cpp/issues/18). **An accepted native `onError` without `onResponse` has not been reproduced.** The initial-idle cleanup change was manually merged by the user in #22 before the controller gate completed. It separately addresses synchronous constructor rejection of a newly submitted batch on an empty idle controller; it does not choose an accepted-worker runtime-error policy, repair response-dispatched constructor failures, or prove facade-level behavior. The fixture-only follow-up replaces an unsupported process-inspection API for 20 LTS. Supported-engine compilation and clean native verification remain pending, not implied by that merge.

```sh
python3 -m unittest discover -s tests -p 'test_controller_lifecycle_tools.py'
python3 scripts/test-controller-lifecycle.py --tool4d "/path/to/tool4d"
```

The runner uses Python's standard library and an explicitly selected macOS tool4d. It creates a unique retained `.build/controller-*` project, byte-copies the current production `_CLI_Controller.4dm`, and records its SHA-256 and checkout HEAD. The fixture graph is:

```text
stub _CLI (currentDirectory only)
  -> actual _CLI_Controller
     -> Schedule subclass (replaces _execute, including staged initial dispatch)
     -> real 4D.SystemWorker (native execution controls)
Probe (native callback recorder, independent of controller)
RejectionProbe (dedicated persistent worker, real controller, guarded reuse)
```

All fixture classes share one owning project, respecting 4D inheritance boundaries. Real, already-terminated tiny workers provide typed identities for synthetic schedules; manually invoked callbacks do **not** establish native scheduling reachability. Native controls use the real controller without the dispatch override. No released components, registry facade, production startup, models, cache mutation, server, installations, rebuilds, or network calls are involved in the local test.

## What a successful characterization means

The native matrix runs `/usr/bin/true`, `/usr/bin/false`, a shell **self-only** TERM attempt, `/bin/sleep 2` with a 0.1-second worker timeout, and a deliberately nonexistent executable. Each accepted command has a three-second wait and targeted worker termination if still running. The signal attempt is recorded exactly as observed; an engine-reported exit 0 is **not** evidence of a signalled native exit. The four accepted controls currently emit `response -> termination`, not native `onError`. False must exit 1. The missing executable must return null without callbacks and synchronously report POSX2; it is not an accepted-worker runtime failure.

The 22 deterministic/native-controller checks are separated by `kind`:

| Kind | Evidence |
| --- | --- |
| `regression` | A response dispatches B before A termination; A termination while B is incomplete preserves B and its wrapper handlers; final release restores public handlers; callback counts/order/receivers/worker arguments/context; later reuse; explicit command abort; actual success/nonzero/timeout queues drain and allow a distinct later worker |
| `candidate` | Synthetic error-without-response retains incomplete A, pending parallel queues and strands a later execute; explicit abort retains message/context queues; synthetic A termination delayed until after B response clears B; directly replayed duplicate termination forwards twice |

Candidate checks intentionally assert the **remaining observed gaps**, not desired corrected behavior. Green means those observations still characterize the source; it does not mean general terminal recovery is fixed. A changed native sequence, missing candidate, failed invariant or altered source behavior requires investigation and updating the characterization deliberately—not silently accepting a new shape.

A completed full run emits `summary.json` with `recoveryFixed:false`,
`acceptedNativeErrorWithoutResponseReproduced:false` and the separate
`idleConstructorRejectionCleanupVerified:true`. No success summary is written
until all strict gates pass.

## Initial-idle constructor rejection regression

The approved narrow policy discards the failed newly submitted batch, including
its siblings, rather than silently continuing it. The controller stages that
batch locally until native construction succeeds. It does not intercept or
translate the original native error. An initial-only options adapter forwards
callbacks with the original controller receiver and arguments; no `Try`/`throw`
or version-floor change is needed. The stored context map is not cleared.

The `rejection` entrypoint creates a uniquely named dedicated worker. Its
process-scoped `RejectionProbe` retains the controller and public callback
identities after startup returns. Seventeen checks cover missing-single,
missing-first-of-batch, repeated failures, original POSX2 error stacks, all three
queues, unchanged saved/public handlers and context map, three actual harmless
reuses, a two-command native queue, old termination while the next worker is
incomplete, callback receiver/context/constructor ordering, owner identity,
a late-event window and directly owned native-worker termination.

**The baseline guard is before reuse:** if failure state or the original error
is wrong, the fixture records `unsafeReusePrevented` and never launches a retry.
It does not attempt to demonstrate runaway recursion. Successful worker callbacks
run after the submitting method returns, without `SystemWorker.wait`. Subsequent
mailbox turns and callbacks record the dedicated worker's number, unique ID,
name and type. The `rejectionProcess` helper uses the legacy
`PROCESS PROPERTIES:C336` outputs, including unique ID and process origin.
It preserves the command token across renaming and does not invent identity
fields when metadata is unavailable: startup records `owner-identity-unavailable`
and enters bounded cleanup without exercising rejection or reuse.
The fixture's scoped local error handler captures expected native errors and is
restored after each rejection; production code installs no handler.

A private shared completion flag keeps only the **headless driver** alive while
the separate worker runs. The driver has a 20-second bound, the worker a
12-second/120-turn bound, plus late/cleanup windows; the external invocation
remains capped at 30 seconds. Only after reporting does the isolated fixture stop
its own worker and quit its disposable engine. These test entrypoints must never
be copied into the live source project.

The default runner still requires diagnostic-free compilation and compiled
execution of all three methods. A separate, explicitly scoped command is
available for interpreted evidence only:

```sh
python3 scripts/test-controller-lifecycle.py --tool4d "/path/to/tool4d" --interpreted-rejection
```

That mode runs native controls plus `rejection`, **not** compilation or the
synthetic schedules, requires `compiledMode:false`, and writes only
`interpreted-rejection-summary.json` after clean exits. Interpreted reports cannot
satisfy the default compiled gate. Do not retry a known crashing local engine
merely to obtain a green run.

The [4D 20](https://developer.4d.com/docs/20/API/SystemWorkerClass) and [21 R4](https://developer.4d.com/docs/21-R4/API/SystemWorkerClass) contracts specify optional `onError` with no response, followed by termination, and distinguish constructor rejection. Source advances on response regardless of exit code; explicit `terminate()` aborts pending commands. No established contract chooses abort versus continue for native runtime error. Any eventual fix needs that decision and identity-aware cleanup: an old worker's termination must not release a newer worker.

Reference workers 20.0.19 (`d58fcbd64eb050fcba658bf576ba18f24c51fad4`) creates a new `_server`/controller when its stored native worker is terminated. Direct controller retention therefore does not prove a public facade restart failure. Production `latest` dependency declarations are unresolved here; the reference source is not proof of installed artifact behavior.

## Strict evidence and validation tiers

In default mode, `Compile project` runs first using the existing small compiler driver, with no component inputs. Success requires `success:true`, an empty diagnostics array (warnings also stop this harness), and exit 0. All three subsequent methods must execute in compiled mode and finish with fresh complete reports, every exact check ID once, no unexpected engine-error/driver-timeout artifact, and exit 0. A green report followed by a shutdown crash fails; exit 0 without a fresh report fails. The runner retains invocation arrays, compiler diagnostics, engine version, raw stdout/stderr, exit/timeout records, per-check checkpoints, native events and the expected rejection diagnostic. Each runtime invocation is capped at 30 seconds; compilation at 120 seconds. Python gate tests exercise stale/missing reports, nonzero exits, timeouts, mode separation, incomplete/duplicate assertions, worker/receiver/error identity and queue/context contamination.

Local validation uses **21 R4 build 21R4.100208**. The dedicated read-only `Controller lifecycle characterization` Actions workflow uses the existing integrity workflow's official macOS arm64 **20.8 archive pinned by SHA-256**, verifies code signing, then runs this fixture without dependencies. It has only `contents:read`, uploads diagnostic artifacts even on failure, and never invokes publication. Hosted results are separate evidence and must be read from the actual run; a local 21 R4 pass is not a hosted 20.8 pass.

Exact 20.7, Windows 4D, actual accepted native error-without-response, facade scheduling, live-server readiness and inference remain unverified. Synthetic schedules, real 4D compilation, real compiled execution, and real accepted-native controls are distinct tiers. No merge or production rollout is implied by this investigation PR.

The initial hosted 20.8 run [41672156148](https://github.com/miyako/llama-cpp/actions/runs/41672156148) correctly stopped at compiler diagnostics: direct comparisons of typed object/function references in the fixture were accepted locally on 21 R4 but rejected on 20.8. The fixture now uses the documented [Collection.indexOf object-reference search](https://developer.4d.com/docs/20/API/CollectionClass#indexof), with same-reference and distinct-empty-object controls. No production source changed and no diagnostics were waived; the initial failed run remains visible.

After that fixture correction, the local 21 R4 attempt `.build/controller-f7a7uw0v` emitted a fresh `success:true/errors:[]` compiler report but exited **-11 at shutdown**. The runner correctly failed and did not execute either test method. This is not a clean compilation/execution pass for the corrected fixture; the independently hosted 20.8 run is a separate validation path, not a way to relabel the local failure.

### Idle-rejection patch evidence before hosted verification

The production controller SHA-256 for the current attempt is
`4d840f8014f149156fcb393e2945908814ce4b98c5897057a2a56e3e73b82bf6`.
The 21 R4 build 100208 interpreted attempt `.build/controller-9k9n7jk9` had
clean-exit native controls and actual guarded reuse observations, but its worker
report was incomplete because the initial headless driver returned too early.
That attempt failed the evidence gate.

After adding only the bounded driver lifetime coordination,
`.build/controller-s5347i8j` encountered **native control shutdown exit -11**.
No native/compile retry was performed. A separate first invocation of the
corrected worker entrypoint produced a fresh complete interpreted report with
**all 17 checks true, errors empty, four original POSX2 stacks, three actual
successful reuses, the native two-command queue, matched owner/callback identity
across later mailbox turns, and all five child workers terminated**, then also
exited **-11**. Its report passes offline structural checks, but the strict
runtime gate **fails**. No success summary was generated.

All further local engine attempts stopped. Ten Python gate tests pass. At that
point no compilation of this new patch, clean-exit worker pass, new 20.7/20.8
execution, new hosted verification or production/facade validation was claimed.
Historical hosted passes applied only to the earlier characterization, not this
patch. The user subsequently approved the independent hosted verification
described below, not more retries of this host's shutdown failure.

The local interpreted report above predates the fixture-only process-identity
helper. It does not verify the current fixture or establish 20 LTS compatibility.
The follow-up review changes tests/documentation only, not the already merged
controller, publisher workflow or release policy. Hosted results must be bound to
their actual source head, checksum-pinned engine, diagnostics and exit records.

The original un-tokenized `Process info` calls failed hosted 20.8 compilation.
That name-resolution failure alone did not establish command-ID availability.
Static inspection of the actual 20.8 build 20.102083 command catalog independently
found 1827 command entries and no C1843; its C336 is procedural `PROCESS PROPERTIES`.
In 21 R4, C336 is renamed `_O_PROCESS PROPERTIES` and C1843 is the distinct
object-returning `Process info`. A suffix preserves command identity across a
rename; it cannot add a command absent from the older engine.

Follow-up run [41742023358](https://github.com/miyako/llama-cpp/actions/runs/41742023358)
compiled cleanly on pinned 20.8 and completed the compiled native matrix (2 checks)
and schedules (22 checks), all with exit 0. Its first C1495 process-activity helper
did not return a usable `processes` collection in tool4d; the owning worker emitted
identity errors and the driver reached its bound without a worker report.
The strict gate failed despite exit 0. The C336 helper and startup guard replace
that failed approach, but require a new actual hosted result; compilation does
not prove runtime metadata support, and no owner-identity gate is waived.
