# llama
### The public entry point for managing a `llama-server` instance.
> llama.new (port : Integer; huggingfaces : cs.event.huggingfaces; HOME : 4D.Folder; options : Object; event : cs.event.event)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| port | Integer | -> | Port to listen on (default: 8080) |
| huggingfaces | cs.event.huggingfaces | -> | Model download parameters |
| HOME | 4D.Folder | -> | Home folder (default: `Folder(fk home folder).folder(".GGUF")`) |
| options | Object | -> | Command-line options passed to `llama-server` |
| event | cs.event.event | -> | Callback functions (onError, onSuccess, onData, onResponse, onTerminate) |

## Description

`cs.llama.llama` is the main class you instantiate to manage a `llama-server` process. It extends `_interface` and orchestrates the full lifecycle: checking whether a server is already running on the given port, downloading model files from Hugging Face if needed, and starting the server process in the background via a worker.

If a server is already running on the specified `port`, the constructor exits immediately without starting a new one.

Parameter defaults applied by the constructor:

- `port`: defaults to `8080` if `0`, negative, or greater than `65535`
- `HOME`: defaults to `Folder(fk home folder).folder(".GGUF")` if not provided or non-existent
- `huggingfaces`: defaults to an empty `cs.event.huggingfaces` collection if `Null`

The `options` object maps directly to `llama-server` CLI flags. Underscores in property names are converted to hyphens (e.g. `n_gpu_layers` → `--n-gpu-layers`). Boolean `true` values produce flags without a value (e.g. `embeddings: True` → `--embeddings`). File and Folder objects are automatically path-escaped for the current platform.

### options properties (common)

| Property | Type | CLI flag | Description |
| --- | --- | --- | --- |
| model | 4D.File | `--model` | Path to the GGUF model file |
| models_preset | 4D.File | `--models-preset` | INI file for router mode |
| models_dir | 4D.Folder | `--models-dir` | Directory for router mode |
| embeddings | Boolean | `--embeddings` | Enable embedding endpoint |
| pooling | Text | `--pooling` | Pooling strategy (`mean`, `cls`, `last`) |
| ctx_size | Integer | `--ctx-size` | Context window size |
| batch_size | Integer | `--batch-size` | Batch size |
| ubatch_size | Integer | `--ubatch-size` | Micro-batch size |
| parallel | Integer | `--parallel` | Number of parallel sequences |
| threads | Integer | `--threads` | Inference threads |
| threads_batch | Integer | `--threads-batch` | Batch threads |
| threads_http | Integer | `--threads-http` | HTTP server threads |
| n_gpu_layers | Integer | `--n-gpu-layers` | Layers to offload to GPU (`-1` = all) |
| temp | Real | `--temp` | Sampling temperature |
| top_k | Integer | `--top-k` | Top-K sampling |
| top_p | Real | `--top-p` | Top-P sampling |
| repeat_penalty | Real | `--repeat-penalty` | Repetition penalty |
| flash_attn | Text | `--flash-attn` | Flash attention (`"on"`) |
| jinja | Boolean | `--jinja` | Enable Jinja templating |
| cache_type_k | Text | `--cache-type-k` | KV cache type for K |
| cache_type_v | Text | `--cache-type-v` | KV cache type for V |
| log_file | 4D.File | `--log-file` | Log output file |
| log_disable | Boolean | `--log-disable` | Disable logging |

## Examples

### Minimal (defaults)

```4d
var $llama : cs.llama.llama
$llama:=cs.llama.llama.new()
```

### Chat completion

```4d
var $homeFolder : 4D.Folder
$homeFolder:=Folder(fk home folder).folder(".GGUF")

var $event : cs.event.event
$event:=cs.event.event.new()
$event.onError:=Formula(ALERT($2.message))
$event.onSuccess:=Formula(ALERT($2.models.extract("name").join(",")+" loaded!"))

var $huggingface : cs.event.huggingface
$huggingface:=cs.event.huggingface.new(\
    $homeFolder.folder("Llama-3.2-3B-Instruct-Q4_K_M"); \
    "hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF"; \
    "Llama-3.2-3B-Instruct-Q4_K_M.gguf")

var $huggingfaces : cs.event.huggingfaces
$huggingfaces:=cs.event.huggingfaces.new([$huggingface])

var $options : Object
$options:={\
    ctx_size: 32768; \
    threads: 4; \
    n_gpu_layers: -1; \
    jinja: True; \
    log_disable: True}

var $llama : cs.llama.llama
$llama:=cs.llama.llama.new(8082; $huggingfaces; $homeFolder; $options; $event)
```

### Terminate the server

```4d
var $llama : cs.llama.llama
$llama:=cs.llama.llama.new()
$llama.terminate()
```

### Router mode (multiple models via INI)

```4d
var $iniFile : 4D.File
var $ini : Collection
$ini:=[]
$ini.push("version = 1")
$ini.push("[bge-m3]")
$ini.push("model = "+$homeFolder.file("bge-m3/bge-m3-Q8_0.gguf").path)
$ini.push("pooling = cls")
$iniFile:=$homeFolder.folder("llama-8888").file("models.ini")
$iniFile.setText($ini.join("\n"))

$options:={embeddings: True; models_preset: $iniFile; n_gpu_layers: 99}
$llama:=cs.llama.llama.new(8888; Null; $homeFolder; $options; $event)
```

## See also

- [`_interface`](_interface.md) — parent class providing `terminate()` and TCP-check helpers
- [`_models`](_models.md) — download and model lifecycle management
- [`_Model`](_Model.md) — concrete model subclass
- [`_server`](_server.md) — CLI wrapper for `llama-server`
