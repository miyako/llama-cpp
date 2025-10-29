![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama.cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama.cpp/total)

# llama.cpp
Local inference engine (repository name changed to comply with dependency manager)

> [!WARNING]
> Windows CLI is built without `libcurl`.
> That means network feature such as
> ```
> -hf elyza/Llama-3-ELYZA-JP-8B-GGUF:Q4_K_M
> ```
> only works on Mac.

## Note for CMake

#### for `x86_64`

* set `GGML_CPU` to `FALSE`
* set `CMAKE_OSX_ARCHITECTURES`  to `x86_64`

#### for Windows

* set `LLAMA_CURL` to `FALSE`

c.f. https://github.com/ggml-org/llama.cpp/issues/9937

#### for All

* set `BUILD_SHARED_LIBS` to `FALSE`
