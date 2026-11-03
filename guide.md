---
layout: default
title: Integration guide
description: Model downloads, server options, router mode, and AI Kit integration for the llama.cpp 4D component.
---

![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](https://github.com/miyako/llama-cpp/blob/main/LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# Integration guide

Use the `llama` component to manage a local `llama-server` process from 4D. For platform details and a first HTTP request, see the [overview]({{ '/' | relative_url }}).

Download a component from [Releases](https://github.com/miyako/llama-cpp/releases), install it in your project's `Components` folder, and install the dependencies declared in the component's [`dependencies.json`](https://github.com/miyako/llama-cpp/blob/main/llama-cpp/Project/Sources/dependencies.json). The examples below use the `event` component for model downloads and callbacks.

## Managed download integrity

The source component also requires the separate [`miyako/hash`](https://github.com/miyako/hash) component, pinned to **20.0.1** rather than `latest`. Install that component alongside the other dependencies; do not copy its CLI into the llama component. The hash component owns its native resources and process handling. Previously published llama component archives are not retroactively changed by this source update.

The reviewed component ZIP and source revision are recorded in [`dependencies.lock.json`](https://github.com/miyako/llama-cpp/blob/main/dependencies.lock.json). This is verification evidence, not an automatic checksum feature of 4D's Dependency Manager. Verify the archive SHA-256 before manual installation or use the regression runner's `--hash-archive` option. On macOS, the release also provides a Developer ID-signed, notarized, stapled DMG; the ZIP's native payloads are signed and notarized, but ZIPs and raw binaries cannot themselves be stapled.

For managed Hugging Face downloads with a valid `lfs.oid` SHA-256, both existing cached files and newly transferred files must match the provider digest before server launch. A same-size corrupt file is not a cache hit. Verification performs an extra complete read of each file on each managed attempt; the streaming helper avoids a whole-model 4D Blob allocation and has a default per-file deadline of 300 seconds.

On a mismatch or hash-helper error, `event.onError` receives `(options; error)` with the model as `This`. Integrity errors use code `3`, with `file`, `expectedDigest`, `actualDigest`, and diagnostic `details`. The attempt stays blocked: no automatic delete, redownload, or metadata refresh occurs. Inspect the reported destination and provider revision, repair it explicitly, then create a new wrapper attempt. Hugging Face `main` can move between metadata lookup and transfer; a mismatch is not silently retried against changed metadata.

Missing/malformed supported digest metadata preserves the legacy size-based path as **unverified**. Offline/local starts and router configurations without managed metadata remain unverified; this is not authentication of arbitrary local/router files. Git `oid` and `xetHash` are not treated as payload SHA-256.

Download `onResponse` still means **HTTP transfer completion**, before integrity verification. `onSuccess` still means **server launch requested**, not readiness or successful inference. Callback receivers/argument order and intentional quiet native stdout/stderr defaults are unchanged. This work does not cancel other transfers already in flight.

## Router mode

Configure multiple models in a preset file. Create the containing folder before writing the preset:

```4d
$n_gpu_layers:=99

var $iniFile : 4D.File
var $ini : Collection

$ini:=[]
$ini.push("version = 1")

$ini.push("[embeddinggemma]")
$ini.push("model = "+$homeFolder.file("embeddinggemma-300m/embeddinggemma-300m-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[bge-m3]")
$ini.push("model = "+$homeFolder.file("bge-m3/bge-m3-Q8_0.gguf").path)
$ini.push("pooling = cls")

$ini.push("[Qwen3-Embedding-0.6B]")
$ini.push("model = "+$homeFolder.file("Qwen3-Embedding-0.6B/Qwen3-Embedding-0.6B-Q8_0.gguf").path)
$ini.push("pooling = last")

$port:=8888
$folder:=$homeFolder.folder("llama-"+String($port))
$folder.create()

$iniFile:=$folder.file("models.ini")
$iniFile.setText($ini.join("\n"))

$max_position_embeddings:=1024
$batch_size:=$max_position_embeddings
$ubatch_size:=$max_position_embeddings

$batches:=2
$threads:=2
$threads_batch:=2

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not($logFile.exists))
    $logFile.setContent(4D.Blob.new())
End if 

$options:={\
embeddings: True; \
models_preset: $iniFile; \
ctx_size: $max_position_embeddings*$batches; \
batch_size: $batch_size*$batches; \
ubatch_size: $ubatch_size; \
parallel: $batches; \
threads: $threads; \
threads_batch: $threads_batch; \
threads_http: $batches+1; \
log_file: $logFile; \
log_disable: False; \
n_gpu_layers: $n_gpu_layers}

$llama:=cs.llama.llama.new($port; Null; $homeFolder; $options; $event)
```

## Usage

Instantiate `cs.llama.llama` in your *On Startup* database method:

```4d
var $llama : cs.llama.llama

If (False)
    $llama:=cs.llama.llama.new()  //default
Else 
    var $homeFolder : 4D.Folder
    $homeFolder:=Folder(fk home folder).folder(".GGUF")
    var $file : 4D.File
    var $URL : Text
    var $port : Integer
    var $huggingface : cs.event.huggingface
        
    var $event : cs.event.event
    $event:=cs.event.event.new()
    /*
        Function onError($params : Object; $error : cs.event.error)
        Function onSuccess($params : Object; $models : cs.event.models)
        Function onData($request : 4D.HTTPRequest; $event : Object)
        Function onResponse($request : 4D.HTTPRequest; $event : Object)
        Function onTerminate($worker : 4D.SystemWorker; $params : Object)
    */
    
    $event.onError:=Formula(ALERT($2.message))
    $event.onSuccess:=Formula(ALERT($2.models.extract("name").join(",")+" loaded!"))
    $event.onData:=Formula(LOG EVENT(Into 4D debug message; This.file.fullName+":"+String((This.range.end/This.range.length)*100; "###.00%")))
    $event.onData:=Formula(MESSAGE(This.file.fullName+":"+String((This.range.end/This.range.length)*100; "###.00%")))
    $event.onResponse:=Formula(LOG EVENT(Into 4D debug message; This.file.fullName+":download complete"))
    $event.onResponse:=Formula(MESSAGE(This.file.fullName+":download complete"))
    $event.onTerminate:=Formula(LOG EVENT(Into 4D debug message; (["process"; $1.pid; "terminated!"].join(" "))))
    
    /*
        embeddings
    */
    
    $port:=8083
    
    $folder:=$homeFolder.folder("jina-embeddings-v4-text-matching-Q4_K_M")  //where to keep the repo
    $path:="jina-embeddings-v4-text-matching-Q4_K_M.gguf"  //path to the file
    $URL:="jinaai/jina-embeddings-v4-text-matching-GGUF"  //path to the repo
    
    $huggingface:=cs.event.huggingface.new($folder; $URL; $path)
    $huggingfaces:=cs.event.huggingfaces.new([$huggingface])
    
    $options:={\
        embeddings: True; \
        pooling: "mean"; \
        threads: 4; \
        threads_batch: 4; \
        threads_http: 4; \
        log_disable: True; \
        n_gpu_layers: -1}

    $llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
    
    /*
        chat completion
    */
    
    $port:=8082
    
    $folder:=$homeFolder.folder("Llama-3.2-3B-Instruct-Q4_K_M")  //where to keep the repo
    $path:="Llama-3.2-3B-Instruct-Q4_K_M.gguf"  //path to the file
    $URL:="hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF"  //path to the repo
    
    $huggingface:=cs.event.huggingface.new($folder; $URL; $path)
    $huggingfaces:=cs.event.huggingfaces.new([$huggingface])
    
    $options:={\
        ctx_size: 32768; \
        batch_size: 4096; \
        threads: 4; \
        threads_batch: 4; \
        threads_http: 4; \
        temp: 0.3; \
        top_k: 40; \
        top_p: 0.9; \
        log_disable: True; \
        repeat_penalty: 1; \
        n_gpu_layers: -1; \
        jinja: True; \
        flash_attn: "on"; \
        cache_type_v: "q8_0"; \
        cache_type_k: "q8_0"}
    
    $llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
    
End if  
```

Unless the server is already running (in which case the constructor does nothing), the following procedure runs in the background:

1. The specified model is downloaded via HTTP
2. The `llama-server` program is started

Now you can test the server:

```
curl -X POST http://127.0.0.1:8083/v1/embeddings \
     -H "Content-Type: application/json" \
     -d '{"input":"The quick brown fox jumps over the lazy dog."}'
```

Or, use AI Kit:

```4d
var $AIClient : cs.AIKit.OpenAI
$AIClient:=cs.AIKit.OpenAI.new()
$AIClient.baseURL:="http://127.0.0.1:8083/v1"

var $text : Text
$text:="The quick brown fox jumps over the lazy dog."

var $responseEmbeddings : cs.AIKit.OpenAIEmbeddingsResult
$responseEmbeddings:=$AIClient.embeddings.create($text)
```

Finally to terminate the server:

```4d
var $llama : cs.llama.llama
$llama:=cs.llama.llama.new()
$llama.terminate()
```

## Vision

`llama-server` supports OCR if you use a model converted to .gguf. `Q4_K_M` is generally considered a best level of quantisation for OCR. However, `llama-server` does not support the `/v1/files` API so you need to reference the image via a data URI in your chat completion request.

## AI Kit compatibility

The API is compatible with the following [Open AI](https://platform.openai.com/docs/api-reference/) endpoints:

|Class|API|Availability|
|-|-|:-:|
|Models|`/v1/models`|✅|
|Chat|`/v1/chat/completions`|✅|
|Images|`/v1/images/generations`||
|Moderations|`/v1/moderations`||
|Embeddings|`/v1/embeddings`|✅|
|Files|`/v1/files`||
