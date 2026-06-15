# _CLI_Controller
### Manages a queue of `4D.SystemWorker` commands for a `_CLI` instance.

> _CLI_Controller.new (CLI : cs.llama._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.llama._CLI | -> | The owning `_CLI` instance |

## Description

`_CLI_Controller` serializes an ordered queue of shell commands, executing each one in its own `4D.SystemWorker` and advancing to the next only after the previous worker has terminated. It is attached to a `_CLI` instance and is not used directly by application code.

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

#### terminate ()

Aborts the queue, clears all pending commands, terminates the active worker, and resets internal state.

## See also

- [`_CLI`](_CLI.md) — owns and instantiates the controller
- [`_llama_Controller`](_llama_Controller.md) — extends `_CLI_Controller` with llama-specific termination handling
