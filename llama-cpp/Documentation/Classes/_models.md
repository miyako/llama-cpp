# _models
### Abstract base class that resolves Hugging Face model metadata and manages file downloads.

> _models.new (port : Integer; huggingfaces : cs.event.huggingfaces; options : Object; formula : 4D.Function; event : cs.event.event)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| port | Integer | -> | Port stored in `options.port` |
| huggingfaces | cs.event.huggingfaces | -> | One or more Hugging Face model descriptors |
| options | Object | -> | Server options object (mutated to add `port`, `onTerminate`, `onStdErr`, `onStdOut`) |
| formula | 4D.Function | -> | Internal response callback forwarded to the download helper |
| event | cs.event.event | -> | Callback functions |

## Description

`_models` is the download-and-startup orchestrator. On construction it iterates the `huggingfaces` collection, queries the Hugging Face API to resolve file metadata (Git OID, size, path, LFS metadata), and builds an internal `files` queue. If the network is unreachable the class sets `offline: true` and skips downloading.

URL formats accepted in `huggingface.URL`:

| Format | Example |
| --- | --- |
| Full HTTPS URL | `https://huggingface.co/user/repo` |
| Short `user/repo` path | `hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF` |

### Properties

| Property | Type | Description |
| --- | --- | --- |
| huggingfaces | cs.event.huggingfaces | Original descriptor collection |
| files | Collection | Resolved file metadata objects pending download |
| options | Object | Merged server options |
| event | cs.event.event | Callback functions |
| offline | Boolean | `True` when the Hugging Face API could not be reached |
| integrity | Object | `status` (`unverified`, `verified`, or `failed`), `failed`, per-file `results`, and `error` on failure |

### Methods

#### download ()

Dispatches the pending files once per instance. Assigns a unique internal completion identity to each destination before dispatch, so inline cached completions and out-of-order HTTP completions cannot remove another destination with the same Git OID. Repeated dispatches are ignored with a diagnostic.

When `lfs.oid` is a 64-hex SHA-256, an existing file is hashed even if its size differs from the metadata. It is never handed to the downloader for automatic replacement on an integrity mismatch. A completed managed download goes through the same gate. Hashing is delegated to the separately installed `cs.hash.hash` component, which reads through its streaming native CLI rather than loading a model into a 4D Blob.

Without a supported provider digest, the existing size-based cache hit and download behavior is preserved, but recorded as `unverified`. The top-level tree `oid` is a Git blob identifier, **not** the LFS payload SHA-256; `xetHash` is not substituted.

#### onDownload (oid : Text {; downloadId : Text})

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| oid | Text | -> | OID of the file that finished downloading |
| downloadId | Text | -> | Optional internal identity supplied by the managed completion adapter |

Verifies the completed destination before removing it from `files`. OID-only calls remain accepted and verify each matching pending destination separately. Duplicate, unknown, and reentrant callbacks do not cause another start. When all destinations have been accepted, it calls `start()` once. `integrity.status` becomes `verified` only if every managed destination was verified.

A mismatch, unavailable/failed hash helper, or malformed hash output latches `integrity.failed` and blocks that start attempt, including late completions. A single `cs.event.error` with code `3` is delivered as `event.onError.call(model; options; error)`. It includes `file`, `expectedDigest`, `actualDigest`, and `details` (the hash component's diagnostic result when available). A bounded failure diagnostic is also sent to the 4D debug output, including when there is no usable subscriber. There is no automatic deletion, replacement, metadata refresh, or retry. Already-running transfers are not canceled by this gate.

After inspecting the file/provider revision and repairing the destination explicitly, create a new wrapper attempt. Do not retry the failed instance.

#### models () → cs.event.models *(virtual)*

Returns a `cs.event.models` instance describing the loaded models. The base implementation returns an empty collection. Overridden in [`_Model`](_Model.md).

#### start () *(virtual)*

Called automatically when all downloads complete. The base implementation is a no-op. Overridden in [`_Model`](_Model.md) to launch the server.

## See also

- [`_Model`](_Model.md) — concrete subclass that overrides `models()` and `start()`
- [`llama`](llama.md) — the public entry point
