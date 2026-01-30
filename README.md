![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# llama.cpp
Local inference engine

**aknowledgements**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)

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
