![version](https://img.shields.io/badge/version-20%2B-E23089)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/llama-cpp)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/llama-cpp/total)

# llama.cpp
Local inference engine

**aknowledgements**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)

See [`index.md`](index.md) for component information.

The CLI targets four architectures (the original manual builds used `b9374`):

- macOS Apple Silicon, Intel
- Windows AMD64, ARM64

## Automated build

Run **Actions > Build CLI > Run workflow** on `main`. Enter a published
[ggml-org/llama.cpp release tag](https://github.com/ggml-org/llama.cpp/releases)
(for example `b9374`) and select the component version increment (`patch`,
`minor`, or `major`). The tag is resolved once to a commit shared by all builds.

The workflow builds only `llama-server`, with static llama/ggml and OpenSSL
libraries, no dynamic backends or OpenMP, and no host-specific CPU tuning:

| Product | Build |
| --- | --- |
| `llama-cpp/Resources/bin/macOS/llama-server` | Universal arm64/x86_64, macOS 14+, embedded Metal shaders; OpenSSL `openssl-3.5.9` built from source for each architecture |
| `llama-cpp/Resources/bin/Windows/llama-server.exe` | Visual Studio 2022 x64, static MSVC runtime, bundled `lib/x64` OpenSSL |
| `llama-cpp/Resources/bin/WindowsARM/llama-server.exe` | Visual Studio 2022 ARM64 with ClangCL, static runtime, bundled `lib/arm64` OpenSSL |

System frameworks/DLLs remain dynamically linked. Dependency checks reject
non-system libraries and dynamic Windows runtimes. Native macOS and Windows x64
builds run `--version`; Windows ARM64 is cross-compiled and inspected, not run.
Updating Windows OpenSSL still requires replacing the matching archives under
`lib/` and headers under `include/`. The macOS OpenSSL tag is pinned in the workflow.

The macOS executable is Developer ID signed with hardened runtime and a secure
timestamp, then submitted to Apple's notary service. Only an **Accepted** result
permits publication. Standalone Mach-O executables cannot have a notarization
ticket stapled to them; the existing Publish workflow also signs and notarizes
the containing component distribution. Notarization results and logs are saved
as workflow artifacts.

Signing uses the same repository secrets as Publish:
`APPLE_DEVELOPER_ID_CERTIFICATE`, `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`,
`KEYCHAIN_PASSWORD`, `CODESIGN_APPLE_ID`, `NOTARYTOOL_APPLE_ID`,
`NOTARYTOOL_TEAM_ID`, and `NOTARYTOOL_PASSWORD`. These are Apple credentials;
Windows executables are not Authenticode-signed.

Once every platform succeeds, the workflow replaces and commits all three
bundled executables on `main`, then explicitly dispatches `publish.yml` with the
selected version increment. `GITHUB_TOKEN` pushes do not trigger another workflow
automatically, and the existing Publish path filter does not include these
resource paths. Repository Actions permissions/rules must allow the token to
push to `main` and dispatch workflows. If `main` changes while the binaries are
building, the update fails rather than overwriting newer work; rerun the build.
If only the final Publish dispatch fails after the commit, run Publish manually.

## Manual build reference

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
cmake -B build_arm -G "Visual Studio 17 2022" -A ARM64 -T ClangCL ^
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
cmake --build build_arm --config Release
```
