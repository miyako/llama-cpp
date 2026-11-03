# _CLI_Controller
### Manages a queue of `4D.SystemWorker` commands for a `_CLI` instance.

> _CLI_Controller.new (CLI : cs.llama._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.llama._CLI | -> | The owning `_CLI` instance |

## Description

`_CLI_Controller` serializes an ordered queue of shell commands, executing each one in its own `4D.SystemWorker` and advancing on its response callback. It is attached to a `_CLI` instance and is not used directly by application code.

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
| worker | 4D.SystemWorker | The currently running worker (`Null` when idle) |
| commands | Collection | Pending command strings |

### Event callbacks

The following properties may be set to `4D.Function` values before calling `execute`. If not set in a subclass, they default to the built-in `_onEvent` no-op handler.

| Property | Signature | Description |
| --- | --- | --- |
| onData | ($worker; $params) | Fired when the worker emits stdout data |
| onDataError | ($worker; $params) | Fired when the worker emits stderr data |
| onError | ($worker; $params) | Fired on worker error |
| onResponse | ($worker; $params) | Fired when the worker responds (command finished) |
| onTerminate | ($worker; $params) | Fired when the worker terminates |

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
Construction and commit contain no wait/listening loop. Successful dispatch,
quiet default stream handlers and subsequent response-driven queue advancement
are unchanged. This uses the existing 20.7-compatible language, not `Try`/`throw`.

This narrow rule does not repair previously corrupted/nonempty idle controllers,
change explicit abort behavior, or handle rejection of a later command dispatched
from an earlier worker's response. Those ownership/error-policy cases remain
separate. Do not retry a controller already left with installed wrappers by older
code; use a fresh controller with the corrected source.

#### terminate ()

Aborts the queue, clears all pending commands, terminates the active worker, and resets internal state.

## See also

- [`_CLI`](_CLI.md) — owns and instantiates the controller
- [`_llama_Controller`](_llama_Controller.md) — extends `_CLI_Controller` with llama-specific termination handling
