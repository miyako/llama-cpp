## Windows ARM

MSVC not supported. GGUF heavily relies on specific ARM NEON and fp16 C-intrinsics that Microsoft's native compiler does not support.

```
cmake -B build -DLLAMA_SERVER_SSL=ON -DOPENSSL_ROOT_DIR="C:\openssl-arm64" -DLLAMA_BUILD_TESTS=OFF -DCMAKE_SYSTEM_PROCESSOR=ARM64 -DLLAMA_BUILD_SERVER=ON -DBUILD_SHARED_LIBS=FALSE -DGGML_CCACHE=OFF
```

```
cmake --build build --config Release
```
