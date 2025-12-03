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

Instantiate `cs.llama.llama`  in your *On Startup* database method:

```4d
var $llama : cs.llama.llama

If (True)
    $llama:=cs.llama.llama.new()  //default
Else 
    var $modelsFolder : 4D.Folder
    $modelsFolder:=Folder(fk home folder).folder(".llama-cpp")
    var $lang; $URL : Text
    var $file : 4D.File
    $lang:=Get database localization(Current localization)
    Case of 
        : ($lang="ja")
            $file:=$modelsFolder.file("Llama-3-ELYZA-JP-8B-q4_k_m.gguf")
            $URL:="https://huggingface.co/elyza/Llama-3-ELYZA-JP-8B-GGUF/resolve/main/Llama-3-ELYZA-JP-8B-q4_k_m.gguf"
        Else 
            $file:=$modelsFolder.file("nomic-embed-text-v1.5.f16.gguf")
            $URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
    End case 
    var $port : Integer
    $port:=8080
    $llama:=cs.llama.new($port; $file; $URL; {\
      ctx_size: 2048; \
      batch_size: 2048; \
      threads: 4; \
      threads_batch: 4; \
      threads_http: 4; \
      temp: 0.7; \
      top_k: 40; \
      top_p: 0.9; \
      repea]t_penalty: 1.1})
End if
```

Unless the server is alraedy running (in which case the costructor does nothing), the following procedure runs in the background:

1. The specified model is download via HTTP
2. The `llama-server` program is started

Now you can test the server:

```
curl -X POST http://127.0.0.1:8080/v1/embeddings \
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

#### AI Kit compatibility

The API is compatibile with [Open AI](https://platform.openai.com/docs/api-reference/embeddings). 
