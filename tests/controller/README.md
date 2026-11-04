# Controller lifecycle regressions and native controls

Refs [#24](https://github.com/miyako/llama-cpp/issues/24). **An accepted native
`onError` without `onResponse` has not been reproduced.** The implementation now
supports that explicit documented 4D 20 contract branch without requiring a
native OS-failure trigger. The separately merged #22/#23 synchronous rejection
transaction and its 17 persistent-worker checks remain required.

The approved policy is default continuation after response/error **and native
termination**. Native response/error notifications keep their original timing;
queued progression waits until the optional existing `onTerminate` callback
returns, **before** the next command's side effects.
`abortQueue()` clears pending commands/messages/contexts without terminating
the current worker or suppressing termination. `False` returns are ignored.
No facade response/error forwarding or stream/output-buffering change is made.
The controller getter and custom `_llama_Controller` overrides are the supported
callback bindings; callbacks receive `This=controller` and original arguments.

Original callback error routing is preserved: production installs no handler.
An intentionally resumed callback counts as normal return and may explicitly
abort the queue. An interrupted callback does not authorize dispatch; termination
cleans up if the owner survives. No callback or cleanup is promised after caller
code destroys that owner. The supported positive suite does not replay the
destructive ABORT attempt described below. See the production
[ordering migration and callback policy](../../llama-cpp/Documentation/Classes/_CLI_Controller.md).

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
LifecycleProbe (separate persistent worker, synthetic error schedules/native controls)
```

All fixture classes share one owning project, respecting 4D inheritance boundaries. Real, already-terminated tiny workers provide typed identities for synthetic schedules; manually invoked callbacks do **not** establish native scheduling reachability. Native controls use the real controller without the dispatch override. No released components, registry facade, production startup, models, cache mutation, server, installations, rebuilds, or network calls are involved in the local test.

## What successful verification means

The native matrix runs `/usr/bin/true`, `/usr/bin/false`, a shell **self-only** TERM attempt, `/bin/sleep 2` with a 0.1-second worker timeout, and a deliberately nonexistent executable. Each accepted command has a three-second wait and targeted worker termination if still running. The signal attempt is recorded exactly as observed; an engine-reported exit 0 is **not** evidence of a signalled native exit. The four accepted controls currently emit `response -> termination`, not native `onError`. False must exit 1. The missing executable must return null without callbacks and synchronously report POSX2; it is not an accepted-worker runtime failure.

The deterministic/native-controller schedules are classified deliberately:

| Kind | Evidence |
| --- | --- |
| `regression` | Native-timed response/error, then termination notification before B dispatch; default continuation/no handler/ignored False; explicit abort of all pending queues; receiver/original arguments/context/error fields; reentrant response and termination enqueue/abort/terminate/restart; duplicate/stale/generation/worker ownership; delayed A termination after explicit restart preserving B; handler restoration/reuse; native success/nonzero/timeout drain/reuse |
| `candidate` | None in the current corrected schedules. The six old gap characterizations have deliberately become positive regressions; this does not promote synthetic events to native proof. |

The `LifecycleProbe` retains its controllers in a uniquely named dedicated worker
after startup returns. Later mailbox turns simulate accepted error/no-response
continuation and callback abort using retired typed native identities. These
events remain **manual simulation**, including interrupted-notification state.
Native controls separately check nonzero **termination** abort before a queued
`/usr/bin/touch` can create a disposable marker;
no-handler continuation; aborting a still-running sleep without termination;
and preserved callbacks/late-event absence. The marker is checked again after
a bounded late window, not merely inferred from a controller launch count.

The fixture-only resumptive local handler exercises the approved callback-error policy.
The callback deliberately attempts a missing native executable (synchronous
POSX2, **not** native `onError`). The handler records the original stack and actual
process identity through the invocation's unique report path, then deliberately
resumes; normal return must continue after termination. Production never
installs or changes that handler. A separate earlier negative ABORT attempt did
not preserve later owner execution and is retained as a boundary, not a positive
test. `lifecycleAbort` is retained only to bind that historical failed probe;
the supported suite never installs it again. A killed owner, missing report or
driver timeout cannot count as a successful surviving-owner test. The fixture
restores its handler outside the error-handling method.

A completed compiled run emits `summary.json` with
`syntheticAcceptedLifecycleRegressionVerified:true`,
`nativeResponseControlsVerified:true`,
`acceptedNativeErrorWithoutResponseReproduced:false`, and
`idleConstructorRejectionCleanupVerified:true`. The old ambiguous `recoveryFixed`
flag is removed from this compiled summary rather than treating a simulation as
general native recovery proof. No success summary is written until all strict
gates pass.

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
reuses, a two-command native queue, termination notification before construction
of the next worker, callback receiver/context/constructor ordering, owner identity,
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

The default runner requires diagnostic-free compilation and compiled
execution of all four methods (`native`, `schedules`, `rejection`, `lifecycle`).
A separate, explicitly scoped command is
available for interpreted evidence only:

```sh
python3 scripts/test-controller-lifecycle.py --tool4d "/path/to/tool4d" --interpreted-rejection
```

That mode runs native controls plus `rejection`, **not** compilation or the
synthetic schedules, requires `compiledMode:false`, and writes only
`interpreted-rejection-summary.json` after clean exits. Interpreted reports cannot
satisfy the default compiled gate. Do not retry a known crashing local engine
merely to obtain a green run.

The [4D 20](https://developer.4d.com/docs/20/API/SystemWorkerClass) contract
specifies `onError` once or `onResponse` once, followed by termination, and
distinguishes constructor rejection. The approved implementation advances after either result and termination,
regardless of exit code, unless callback code explicitly aborts.
Private identity-owned cleanup prevents old termination releasing a newer worker.

Reference workers 20.0.19 (`d58fcbd64eb050fcba658bf576ba18f24c51fad4`) creates a new `_server`/controller when its stored native worker is terminated. Direct controller retention therefore does not prove a public facade restart failure. Production `latest` dependency declarations are unresolved here; the reference source is not proof of installed artifact behavior.

## Strict evidence and validation tiers

In default mode, `Compile project` runs first using the existing small compiler
driver, with no component inputs. Success requires `success:true`, an empty
diagnostics array (warnings also stop this harness), and exit 0. All four methods
must execute in compiled mode and finish with fresh complete reports, every exact
check ID once, no unexpected engine-error/driver-timeout artifact, and exit 0.
A green report followed by a shutdown crash fails; exit 0 without a fresh report
fails. The runner retains invocation arrays, compiler diagnostics, source SHA/HEAD,
engine version, raw stdout/stderr, exit/timeout records and callback/error/owner
evidence. Each invocation is capped at 30 seconds; compilation at 120 seconds.
Python tests reject malformed or misclassified evidence rather than weaken gates.

Local engine retries are prohibited for this patch because prior 21 R4 and
private 20.8 attempts crashed at shutdown. Local validation is Python/static only.
The read-only `Controller lifecycle characterization` workflow uses the official
macOS arm64 **20.8 archive pinned by SHA-256**, verifies signing, and runs without
components. It has only `contents:read`, uploads artifacts even on failure, and
never invokes publication. Hosted results must be read from the actual new run;
the historical green #23 run does not validate this changed source.

Exact 20.7, Windows 4D, actual accepted native error-without-response, facade scheduling, live-server readiness and inference remain unverified. Synthetic schedules, real 4D compilation, real compiled execution, and real accepted-native controls are distinct tiers. No merge or production rollout is implied by this investigation PR.

## Diagnostic findings that required the approved timing migration

Run [41757854630](https://github.com/miyako/llama-cpp/actions/runs/41757854630)
at PR head `a4e0d0306188d91764806477dbc04c95ac62b09f` compiled cleanly on
official pinned 20.8 build 102083 (`F0012008`). The native 2-check matrix,
51 schedules and unchanged 17 rejection checks completed with clean exits.
The new persistent lifecycle method **failed**: its nonzero-at-response assertion
is false, and its ABORT attempt did not produce a later complete owner report.
The strict gate remains red; no success summary exists.

The tiny native `/usr/bin/true` and `/usr/bin/false` controls show exactly
`{type:"response"}`, then `{type:"termination"}` as native event objects.
`worker.exitCode` is undefined at response and becomes 0/1 at termination.
The fixture must not treat a synthetic retired worker's already-known exit code,
an undefined value, or stdout payload as native status-before-dispatch proof.
The user explicitly approved keeping response notification at native timing and
advancing only after the existing termination callback. The revised patch tests
nonzero abortion there, rather than fabricating response-time status.
Those source/fixture changes require a new hosted run; the earlier 51-check
passes do not verify the revised 72-check progression.

The ABORT fixture's handler captured original POSX2, current process 2 and
`LifecycleProbe.response` as the error source, but later queued owner ticks
did not execute, even when enqueued before yielding. The driver timed out.
This is an observed owner/control-flow boundary, **not** a successful
surviving-owner unwind cleanup test or proof of the owner's exact final state.
The failing attempt is retained; no unchanged destructive-ABORT retry is justified.
The current approval preserves caller handlers and promises no callback/cleanup
after caller code destroys the owner.

Earlier run
[41757343167](https://github.com/miyako/llama-cpp/actions/runs/41757343167)
compiled and emitted all 51 true assertions but correctly failed on an unexpected
`Undefined collection` artifact. The new fixture batch now explicitly supplies
aligned message/context arrays rather than exercising the pre-existing omitted
collection-input branch. Run
[41757484042](https://github.com/miyako/llama-cpp/actions/runs/41757484042)
then passed those schedules and original rejection checks, but exposed fixture
identity deep-copying and an invalid process-variable assumption in its error
handler. Native identities are now passed by reference; error handlers capture
through the invocation's unique report path. No diagnostic or clean-exit gate
was waived.

## Historical baseline evidence (before issue #24 implementation)

The following attempts concern earlier source, not verification of the new patch.

The initial hosted 20.8 run [41672156148](https://github.com/miyako/llama-cpp/actions/runs/41672156148) correctly stopped at compiler diagnostics: direct comparisons of typed object/function references in the fixture were accepted locally on 21 R4 but rejected on 20.8. The fixture now uses the documented [Collection.indexOf object-reference search](https://developer.4d.com/docs/20/API/CollectionClass#indexof), with same-reference and distinct-empty-object controls. No diagnostics were waived; the initial failed run remains visible.

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
