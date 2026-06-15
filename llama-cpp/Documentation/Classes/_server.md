# _server
### Extends `_llama` to build and launch the `llama-server` command line.

> _server.new (controller : 4D.Class)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| controller | 4D.Class | -> | Optional custom controller class |

## Description

`_server` extends [`_llama`](_llama.md) (with `command = "server"`) and provides the `start` method, which assembles the full `llama-server` command string from an options object and launches it via `_CLI_Controller.execute`.

`_server` is never instantiated directly by application code. It is managed internally by the worker infrastructure; `cs.llama.llama` delegates to it via `cs.llama.workers.worker`.

### Methods

#### start (option : Object) → 4D.SystemWorker

Builds the CLI command and starts the server.

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| option | Object | -> | Server options (see [llama](llama.md) for the full property list) |
| Result | 4D.SystemWorker | <- | The launched worker |

**Argument construction rules:**

| Value type | CLI form |
| --- | --- |
| Real / Integer | `--flag value` |
| Text | `--flag escaped-value` |
| Boolean `True` | `--flag` (no value) |
| 4D.File (exists) | `--flag escaped-path` |
| 4D.Folder (exists) | `--flag escaped-path` |
| Collection | Flag repeated for each element |

The `model` property receives special treatment: it is always emitted first as `--model <path>` before the remaining options. The keys `model`, `model_url`, `help`, and `version` are skipped in the general loop. All other option keys have underscores replaced with hyphens.

**Environment variables** — before launching, `_server` creates two temporary folders and injects them as environment variables:

| Variable | Purpose |
| --- | --- |
| `HF_HUB_CACHE` | Overrides Hugging Face cache directory |
| `LLAMA_CACHE` | Overrides llama.cpp cache directory |

Both folders are created fresh on each `start` call to prevent stale cache interference.

## Examples

`_server` is used indirectly via `cs.llama.llama`:

```4d
var $llama : cs.llama.llama
$llama:=cs.llama.llama.new(8080; $huggingfaces; $homeFolder; $options; $event)
```

To terminate the server from the same (or any) context:

```4d
$llama:=cs.llama.llama.new()
$llama.terminate()
```

## See also

- [`_llama`](_llama.md) — parent class
- [`_CLI_Controller`](_CLI_Controller.md) — executes the assembled command
- [`_Model`](_Model.md) — calls `_server.start` after model download completes
