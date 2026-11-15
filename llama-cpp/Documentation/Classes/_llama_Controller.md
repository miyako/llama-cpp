# _llama_Controller
### Extends `_CLI_Controller` with llama-specific worker termination handling.

> _llama_Controller.new (CLI : cs.llama._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.llama._CLI | -> | The owning `_CLI` (typically a `_server` instance) |

## Description

`_llama_Controller` is the default controller used by all `_llama` subclasses. It inherits all queueing and execution behaviour from [`_CLI_Controller`](_CLI_Controller.md) and overrides only `onTerminate` to forward the termination event back to the owning `_llama` instance's `onTerminate` callback.

This allows application code to attach a single `onTerminate` function on the `_server` (or `llama`) instance and have it called automatically when the `llama-server` process exits.

Response/error lifecycle bookkeeping is private in `_CLI_Controller` and does
not depend on forwarding either event here. Aggregate `onResponse` forwarding
remains disabled by default; stdout/stderr handling and buffering are unchanged.
To discard dependent commands, an existing custom controller override can call
`This.abortQueue()` from `onError` or from `onResponse` using application criteria.
These callbacks run **before** the next queued command, unlike the former
response ordering. Return values such as `False` do not abort the queue.
On the tested 20.8 engine, native `exitCode` is not available during `onResponse`;
do not use an undefined value as proof of nonzero exit. Queue progression now
waits until `onTerminate` returns, so this existing callback can inspect normal
native exit status and call `This.abortQueue()` before dependents start.
See the parent's [callback and error policy](_CLI_Controller.md#event-callbacks).

### Overridden event callbacks

The following callbacks are declared (but intentionally left as no-ops) and may be overridden in a subclass:

| Property | Description |
| --- | --- |
| onData | stdout data event |
| onDataError | stderr data event |
| onResponse | response / command-complete event |
| onError | worker error event |

#### onTerminate ($worker : 4D.SystemWorker; $params : Object)

Called when the managed `SystemWorker` terminates. Looks up `onTerminate` on the owning `_server` instance and calls it if present.

The receiver remains the controller. For the current generation its `worker`
still identifies the terminating worker; the next queued worker is not constructed
until the callback returns normally. Explicit terminate/restart replaces the
generation and prevents old completion from dispatching again. A delayed old
termination retains its original worker argument even if `controller.worker`
already identifies a replacement.

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| $worker | 4D.SystemWorker | -> | The worker that terminated |
| $params | Object | -> | Termination parameters from the system worker |

## Examples

### Custom controller subclass

stdout/stderr are quiet by default on purpose: a long-running server can produce a large amount of output. Prefer `log_file` in the server options. If you do handle streams, keep the handler bounded (do not accumulate the data). A subclass of `_llama_Controller` can override `onData`:

```4d
// In your custom controller class (e.g. cs.llama.MyController):
Class extends cs.llama._llama_Controller

Function onData($worker : 4D.SystemWorker; $params : Object)
    LOG EVENT(Into 4D debug message; $params.data)
```

`cs.llama.llama.new()` does not accept a controller and always uses the default `_llama_Controller`. A custom controller is used only when you pass its class to `_server` yourself; `_llama` accepts it when it extends `_llama_Controller`:

```4d
var $server : cs.llama._server
$server:=cs.llama._server.new(cs.MyController)
$server.start($options)  // $options must already contain model, port, etc.
```

This bypasses the facade's port check, Hugging Face download and SHA-256 verification.

## See also

- [`_CLI_Controller`](_CLI_Controller.md) — parent class
- [`_llama`](_llama.md) — attaches this controller by default
- [`_server`](_server.md) — the `_llama` subclass whose `onTerminate` is forwarded here
