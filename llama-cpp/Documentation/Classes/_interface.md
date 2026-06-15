# _interface
### Abstract base class providing shared server lifecycle methods for the llama namespace.

> _interface.new ()

`_interface` has no constructor parameters. It is not instantiated directly; it is extended by [`llama`](llama.md).

## Description

`_interface` is the root class of the `cs.llama` hierarchy. It provides two methods used by all subclasses:

- **`_onTCP`** — a callback invoked after a TCP port-availability check. If the port is free it dispatches a worker to start the server; if the port is already in use it fires `event.onError` with a descriptive message.
- **`terminate`** — gracefully shuts down the running `llama-server` worker.

### _onTCP ($status, $options)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| $status | Object | -> | Result of the TCP port check (`success`, `port`, `PID`) |
| $options | Object | -> | Server options including `name`, `port`, `event` |

Called internally after a port probe. When `$status.success` is `true` the method calls `CALL WORKER` to invoke `start` on the server worker, then registers `onModel` as the response callback. When the port is occupied it constructs a `cs.event.error` and calls `event.onError`.

### terminate ()

Obtains the server worker via `cs.llama.workers.worker` and calls `terminate()` on it. Use this from any context where you hold a reference to the `llama` instance.

## Examples

```4d
// Terminate from anywhere — llama.new() with no arguments returns
// a lightweight handle without starting a new server
var $llama : cs.llama.llama
$llama:=cs.llama.llama.new()
$llama.terminate()
```

## See also

- [`llama`](llama.md) — public subclass that extends `_interface`
- [`_server`](_server.md) — CLI wrapper whose worker is targeted by `terminate()`
