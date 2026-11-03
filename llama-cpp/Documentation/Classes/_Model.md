# _Model
### Extends `_models` to set the model file path and launch `llama-server` after download.

> _Model.new (port : Integer; huggingfaces : cs.event.huggingfaces; options : Object; formula : 4D.Function; event : cs.event.event)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| port | Integer | -> | Port to listen on |
| huggingfaces | cs.event.huggingfaces | -> | Model download parameters |
| options | Object | -> | Command-line options (mutated; `options.model` is set after first file downloads) |
| formula | 4D.Function | -> | Internal response callback |
| event | cs.event.event | -> | Callback functions |

## Description

`_Model` is the concrete implementation of [`_models`](_models.md). After calling `Super` it immediately triggers `download()` unless `offline` is `true`.

It overrides three methods from `_models`:

### _isRouterMode () → Boolean

Returns `true` when the options object indicates router mode — i.e. when `options.models_preset` is an existing `4D.File` or `options.models_dir` is an existing `4D.Folder`.

### models () → cs.event.models

Overrides the virtual base. In router mode it returns a single unnamed model entry. Otherwise it returns a `cs.event.models` collection containing one `cs.event.model` built from `options.model.name` and whether the file currently exists on disk.

### onDownload (oid : Text {; downloadId : Text})

Overrides the virtual base. When a pending file completes, it sets `options.model` to that destination (if not already set and not already assigned to another file option). Then calls `Super.onDownload` to verify its bytes, remove only that pending identity, and trigger `start()` when all downloads are accepted.

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| oid | Text | -> | OID of the completed download |
| downloadId | Text | -> | Optional internal destination identity; OID-only calls remain supported |

### start ()

Overrides the virtual base. Refuses a failed integrity attempt and defers an online start while any managed SHA-256 verification is pending. Otherwise creates a `cs.workers.worker` wrapping `_server`, calls `worker.start(port, options)`, then fires `event.onSuccess` with receiver `model` and arguments `(options; models())`.

The callback retains its existing **launch-request** meaning: it does not prove that the server is listening, healthy, or ready for inference. Offline/local and router configurations without managed metadata retain their explicitly unverified startup behavior; this gate does not enumerate or hash arbitrary files in a router directory.

### Properties

In addition to properties inherited from `_models`:

| Property | Type | Description |
| --- | --- | --- |
| model | 4D.Folder | Set internally after first download resolves the model path |

## See also

- [`_models`](_models.md) — parent class
- [`_server`](_server.md) — launched by `start()`
- [`llama`](llama.md) — public entry point
