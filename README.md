![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# llama.cpp
Local inference engine

**aknowledgements**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)

The CLI is built for `4` platforms:

- macOS Apple Silicon
- macOS Intel
- Windows AMD
- Windows ARM

### Apple Silicon

* set `BUILD_SHARED_LIBS` to `FALSE`
 
### Intel

* set `GGML_CPU` to `FALSE`
* set `CMAKE_OSX_ARCHITECTURES`  to `x86_64`

### Windows

~~set `LLAMA_CURL` to `FALSE`~~
~~c.f. https://github.com/ggml-org/llama.cpp/issues/9937~~

```
cmake -S . -B build -A x64 ^
 -DBUILD_SHARED_LIBS=FALSE ^
 -DCMAKE_TOOLCHAIN_FILE={...\vcpkg\scripts\buildsystems\vcpkg.cmake} ^
 -DLLAMA_BUILD_SERVER=ON

cmake --build build --config Release
```

* open project sith visual studio
* add curl include paths
* add libraries

```
Crypt32.lib
Secur32.lib
Iphlpapi.lib
libcurl.lib
zlib.lib
ws2_32.lib
``` 

* build each target with `MT`

### Windows ARM

ARM NEON and fp16 C-intrinsics not supported by MSVC native compiler. Use `Clang` or `ninja` instead.

```
cmake -B build -G "Visual Studio 17 2022" -A ARM64 -T ClangCL
 -DCMAKE_SYSTEM_PROCESSOR=ARM64
 -DOPENSSL_ROOT_DIR={arm64 openssl dir}
 -DLLAMA_BUILD_TESTS=OFF
 -DLLAMA_BUILD_SERVER=ON
 -DGGML_OPENMP=OFF
 -DGGML_CCACHE=OFF
 -DBUILD_SHARED_LIBS=FALSE
```


```
cmake -B build
 -DCMAKE_SYSTEM_PROCESSOR=ARM64
 -DOPENSSL_ROOT_DIR={arm64 openssl dir}
 -DLLAMA_BUILD_TESTS=OFF
 -DLLAMA_BUILD_SERVER=ON
 -DGGML_OPENMP=OFF
 -DGGML_CCACHE=OFF
 -DBUILD_SHARED_LIBS=FALSE
```

```
cmake --build build --config Release
```
