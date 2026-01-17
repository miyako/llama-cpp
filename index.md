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
    
    $port:=8082
    
    $folder:=$homeFolder.folder("nomic-embed-text-v1.Q8_0")  //where to keep the repo
    $path:="nomic-embed-text-v1.Q8_0.gguf"  //path to the file
    $URL:="nomic-ai/nomic-embed-text-v1-GGUF"  //path to the repo
    
    var $embeddings : cs.event.huggingface
    $embeddings:=cs.event.huggingface.new($folder; $URL; $path; "embedding")
    $huggingfaces:=cs.event.huggingfaces.new([$embeddings])
    
    $options:={\
    embeddings: True; \
    threads: 4; \
    threads_batch: 4; \
    threads_http: 4; \
    log_disable: True; \
    n_gpu_layers: -1}
    
    $llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
    
    /*
        chat completion
    */
    
    $port:=8083
    
    $folder:=$homeFolder.folder("gemma-2-2b-it-Q4_K_M")  //where to keep the repo
    $path:="gemma-2-2b-it-Q4_K_M.gguf"  //path to the file
    $URL:="bartowski/gemma-2-2b-it-GGUF"  //path to the repo
    
    $options:={\
    ctx_size: 2048; \
    batch_size: 2048; \
    threads: 4; \
    threads_batch: 4; \
    threads_http: 4; \
    temp: 0.3; \
    top_k: 40; \
    top_p: 0.9; \
    log_disable: True; \
    repeat_penalty: 1; \
    n_gpu_layers: -1}
    
    $llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
    
End if  
```

Unless the server is already running (in which case the costructor does nothing), the following procedure runs in the background:

1. The specified model is downloaded via HTTP
2. The `llama-server` program is started

Now you can test the server:

```
curl -X POST http://127.0.0.1:8082/v1/embeddings \
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

The API is compatibile with [Open AI](https://platform.openai.com/docs/api-reference/embeddings). 

|Class|API|Availability|
|-|-|:-:|
|Models|`/v1/models`|✅|
|Chat|`/v1/chat/completions`|✅|
|Images|`/v1/images/generations`||
|Moderations|`/v1/moderations`||
|Embeddings|`/v1/embeddings`|✅|
|Files|`/v1/files`||
