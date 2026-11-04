# _CLI_Controller
### Manages a queue of `4D.SystemWorker` commands for a `_CLI` instance.

> _CLI_Controller.new (CLI : cs.llama._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.llama._CLI | -> | The owning `_CLI` instance |

## Description

`_CLI_Controller` serializes an ordered queue of shell commands, executing each one in its own `4D.SystemWorker`. Private bookkeeping handles either a response or an execution error, then advances only after the termination callback returns, independently of public event forwarding. The owning `_CLI` exposes it through its `controller` getter.

The [4D 20 contract](https://developer.4d.com/docs/20/API/SystemWorkerClass)
delivers `onError` once **or** `onResponse` once, then `onTerminate` always.
An accepted native error without response remains unreproduced in this project's
native controls; supporting that documented branch does not claim a native reproduction.

### Properties

| Property | Type | Description |
| --- | --- | --- |
| dataType | Text | Worker data type (`"text"` by default) |
| encoding | Text | Text encoding (`"UTF-8"` by default) |
| variables | Object | Environment variables injected into each worker |
| timeout | Variant | Worker timeout (`Null` = no timeout) |
| hideWindow | Boolean | Hide the console window on Windows (default: `True`) |
| currentDirectory | 4D.Folder | Inherited from the owning `_CLI` |
| SYSTEM_WORKER_CONTEXT | Object | Key-value store keyed by worker PID for per-command context |
| complete | Boolean | `True` when the command queue has been fully drained |
| worker | 4D.SystemWorker | Current accepted worker, retained through its termination callback (`Null` when idle) |
| commands | Collection | Pending command strings |

### Event callbacks

The following properties may be set to `4D.Function` values before calling `execute`. If not set in a subclass, they default to the built-in `_onEvent` no-op handler.

| Property | Signature | Description |
| --- | --- | --- |
| onData | ($worker; $params) | Fired when the worker emits stdout data |
| onDataError | ($worker; $params) | Fired when the worker emits stderr data |
| onError | ($worker; $params) | Optional execution-error callback, before the next queued command |
| onResponse | ($worker; $params) | Optional response callback, before the next queued command |
| onTerminate | ($worker; $params) | Fired when the worker terminates, before the next queued command; normal `exitCode` is available here |

Callbacks keep the controller as `This` and the original worker and event objects
as arguments. Response and error events receive the accepted command's `context`;
existing error fields are not replaced. Each accepted dispatch retains its own
callback/context ownership until termination. Duplicate/stale terminal events do
not notify twice or release a newer worker, including when a callback terminates
and restarts the controller.

**Ordering migration:** previously, the response handler launched the next command
before calling the saved public `onResponse`. Now response/error notifications
stay at their native timing, and **queue progression waits until the optional
public `onTerminate` callback returns**. That callback can inspect the real native
exit status and abort dependents before they have any side effect. During
termination notification for the current generation, `controller.worker` still
identifies the terminating worker, not the next command's worker. A delayed
termination after explicit restart still passes the old worker as its argument;
`controller.worker` then identifies the replacement. After normal callback return, private
bookkeeping rechecks generation ownership and all pending queues before release
and dispatch. Callback code must not assume a dependent command has already
started. Enqueueing in callbacks is supported; `terminate()` followed by
`execute()` explicitly starts a new generation without an extra old-generation
dispatch.

**Queue policy:** remaining commands continue by default, even on execution error
or nonzero exit, or when a component deliberately does not forward the public
event. Call `This.abortQueue()` to discard dependents. Callback return values,
including `False`, are ignored. Aborting then enqueueing explicitly submits new
work; only commands pending at the instant of abort are discarded.

**Callback errors on 20 LTS:** the controller installs no error handler and does
not swallow or translate callback errors. A callback which returns normally,
including after a caller's handler deliberately resumes execution, authorizes
continuation. Such a handler must explicitly call `abortQueue()` if it considers
the callback failed. A callback interrupted by `ABORT` cannot authorize a next
launch. For an interrupted response/error notification, if its owner survives
and receives termination, private cleanup discards pending work and releases
only that dispatch after notification. The controller cannot guarantee
callbacks or cleanup after caller code destroys the owning process. Termination
notification itself must return normally to authorize queued progression.

Quiet default stdout/stderr handlers and `_llama_Controller`'s deliberate lack
of aggregate response/error forwarding are unchanged. No output buffering or
default aggregate response notification is added.

**Native exit-status timing:** the compiled 20.8 controls observe no `exitCode`
on the worker during `onResponse`; the response event itself contains only
`type`. A normal exit code becomes available at `onTerminate`. Do not infer a
nonzero exit from an undefined value or from response output. Inspecting
`worker.exitCode` in `onResponse` is not a supported native status-abort example.
For abnormal termination the code can remain undefined; applications must choose
their own policy for that case rather than treating it as a numeric status.

### Methods

#### execute (command, message, context) → cs.llama._CLI_Controller

Enqueues one or more commands and starts execution if no worker is currently running.

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| command | Text \| Collection | -> | Shell command string, or a collection of command strings |
| message | Variant \| Collection | -> | Optional stdin payload(s) sent to the worker |
| context | Variant \| Collection | -> | Optional per-command context object(s); retrievable via `SYSTEM_WORKER_CONTEXT` in callbacks |
| Result | cs.llama._CLI_Controller | <- | `This` — enables chaining |

When `message` is an Object or Collection it is serialized to JSON before being posted. Blob and Text values are posted as-is. Scalar values are converted with `String()`.

For an idle controller with all three queues empty, the new batch is staged until
the first native worker is constructed successfully. A synchronous constructor
rejection propagates the original native error without installing an error
handler or translating the exception. The failed batch, including sibling
commands, never enters the queues; messages/contexts remain empty, callbacks and
the context map are unchanged, `worker` remains `Null`, and `complete` is `True`.
If a caller's error handler resumes after the native error, a returned null worker
also commits nothing.

The initial worker uses a private options adapter to forward native callbacks
with the original controller as receiver and unchanged worker/event arguments.
Construction and commit contain no wait/listening loop. Quiet default stream
handlers remain unchanged. This uses existing 20 LTS language, not `Try`/`throw`;
exact 20.7 execution requires separate evidence.

This narrow rule does not repair previously corrupted/nonempty idle controllers,
or guarantee recovery from rejection of a later command dispatched
after an earlier worker's termination. Those ownership/error-policy cases remain
separate. Do not retry a controller already left with installed wrappers by older
code; use a fresh controller with the corrected source.

#### abortQueue ()

Clears **all three pending queues**: commands, stdin messages, and contexts.
Does not terminate the active native worker, change the accepted command's context
or historical `SYSTEM_WORKER_CONTEXT` entries, or suppress its termination callback.
The controller is complete until new work is enqueued.

The supported callback binding is the controller's public callback property or
an existing custom `_llama_Controller` subclass override. No new facade event
binding is required:

```4d
// In a custom controller subclass:
Function onError($worker : 4D.SystemWorker; $params : Object)
    This.abortQueue()

Function onTerminate($worker : 4D.SystemWorker; $params : Object)
    If ([This.worker].indexOf($worker)=0) && ([Is real; Is integer].includes(Value type($worker.exitCode)))
        If ($worker.exitCode#0)
            This.abortQueue()
        End if
    End if
```

#### terminate ()

Calls `abortQueue()`, releases the current controller generation, and requests
termination of its native worker. A later old-worker termination is still
notified once, but cannot clear a replacement worker.

## See also

- [`_CLI`](_CLI.md) — owns and instantiates the controller
- [`_llama_Controller`](_llama_Controller.md) — extends `_CLI_Controller` with llama-specific termination handling
