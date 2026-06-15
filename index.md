---
layout: default
---

![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# Use llama.cpp from 4D

#### Abstract

[**llama.cpp**](https://github.com/ggml-org/llama.cpp) is an open-source project that allows you to run Meta's LLaMA language models locally on CPUs without heavy frameworks like PyTorch or TensorFlow. Essentially, it’s a **lightweight C++ implementation optimized for inference**.

#### New!

Router mode is now supported

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

#### Usage

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

Unless the server is already running (in which case the costructor does nothing), the following procedure runs in the background:

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
$AIClient.baseURL:="http://127.0.0.1:8080/v1"

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

#### Vision

`llama-server` supports OCR if you use a model converted to .gguf. `Q4_K_M` is generally considered a best level of quantisation for OCR. However, `llama-server` does not support the `/v1/files` API so you need to reference the image via a data URI in your chat completion request.

#### AI Kit compatibility

The API is compatibile with the following [Open AI](https://platform.openai.com/docs/api-reference/) endpoints: 

|Class|API|Availability|
|-|-|:-:|
|Models|`/v1/models`|✅|
|Chat|`/v1/chat/completions`|✅|
|Images|`/v1/images/generations`||
|Moderations|`/v1/moderations`||
|Embeddings|`/v1/embeddings`|✅|
|Files|`/v1/files`||
