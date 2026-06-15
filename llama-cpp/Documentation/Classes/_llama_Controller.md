# _llama_Controller
### Extends `_CLI_Controller` with llama-specific worker termination handling.

> _llama_Controller.new (CLI : cs.llama._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.llama._CLI | -> | The owning `_CLI` (typically a `_server` instance) |

## Description

`_llama_Controller` is the default controller used by all `_llama` subclasses. It inherits all queueing and execution behaviour from [`_CLI_Controller`](_CLI_Controller.md) and overrides only `onTerminate` to forward the termination event back to the owning `_llama` instance's `onTerminate` callback.

This allows application code to attach a single `onTerminate` function on the `_server` (or `llama`) instance and have it called automatically when the `llama-server` process exits.

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

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| $worker | 4D.SystemWorker | -> | The worker that terminated |
| $params | Object | -> | Termination parameters from the system worker |

## Examples

### Custom controller subclass

To handle stdout while the server is running, create a subclass of `_llama_Controller` and override `onData`:

```4d
// In your custom controller class (e.g. cs.llama.MyController):
Class extends cs.llama._llama_Controller

Function onData($worker : 4D.SystemWorker; $params : Object)
    LOG EVENT(Into 4D debug message; $params.data)
```

Then pass it when constructing the server:

```4d
$llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
// _llama automatically detects MyController extends _llama_Controller
// and uses it in place of the default
```

## See also

- [`_CLI_Controller`](_CLI_Controller.md) — parent class
- [`_llama`](_llama.md) — attaches this controller by default
- [`_server`](_server.md) — the `_llama` subclass whose `onTerminate` is forwarded here
