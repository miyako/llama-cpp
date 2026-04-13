![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# llama.cpp
Local inference engine

**aknowledgements**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)

The CLI is built for `4` platforms:

- macOS Apple Silicon, Intel `8667 (c08d28d08)`
- Windows AMD, ARM `8667 (c08d28d08)`

#### Apple Silicon

```
git clone https://github.com/ggml-org/llama.cpp.git --recursive
cd llama.cpp
```

* Use `cmake.app` with generator=xcode
* Set `BUILD_SHARED_LIBS` to `FALSE`
* `LLAMA_BUILD_SERVER` is `ON` by default
* Set `LLAMA_BUILD_TESTS` to `OFF`
* Set path to static OpenSSL lib, include
* Open Xcode

Build:

- libllama.a
- llama-bench
- llama-cli
- llama-diffusion-cli
- llama-embedding
- llama-gguf
- llama-gguf-split
- llama-imatrix
- llama-perplexity
- llama-quantize
- llama-server
- llama-tokenize
 
#### Intel (on Apple Silicon)

* Back to `cmake.app`
* Set `GGML_CPU` to `FALSE`
* Set `CMAKE_OSX_ARCHITECTURES`  to `x86_64`
* Back to Xcode

### Windows

~~set `LLAMA_CURL` to `FALSE`~~
~~c.f. https://github.com/ggml-org/llama.cpp/issues/9937~~

```
cmake -B build -G "Visual Studio 17 2022" -A x64 ^
 -D OPENSSL_INCLUDE_DIR=C:\Users\miyako\Documents\GitHub\llama-cpp\include ^
 -DOPENSSL_ROOT_DIR=C:\Users\miyako\Documents\GitHub\llama-cpp\lib\x64 ^
 -DLLAMA_BUILD_TESTS=OFF ^
 -DLLAMA_BUILD_SERVER=ON ^
 -DGGML_OPENMP=OFF ^
 -DGGML_CCACHE=OFF ^
 -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
 -DBUILD_SHARED_LIBS=FALSE 
```

### Windows ARM

ARM NEON and fp16 C-intrinsics not supported by MSVC native compiler. Use `Clang` or `ninja`.

```
cmake -B build -G "Visual Studio 17 2022" -A ARM64 -T ClangCL ^
 -DCMAKE_SYSTEM_PROCESSOR=ARM64 ^
 -DOPENSSL_INCLUDE_DIR=C:\Users\miyako\Documents\GitHub\llama-cpp\include ^
 -DOPENSSL_ROOT_DIR=C:\Users\miyako\Documents\GitHub\llama-cpp\lib\arm64 ^
 -DLLAMA_BUILD_TESTS=OFF ^
 -DLLAMA_BUILD_SERVER=ON ^
 -DGGML_OPENMP=OFF ^
 -DGGML_CCACHE=OFF ^
 -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
 -DBUILD_SHARED_LIBS=FALSE
```

```
cmake --build build --config Release
```
