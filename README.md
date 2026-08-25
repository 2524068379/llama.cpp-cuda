# llama.cpp CUDA Builds (unsloth `iq1-narrow` fork)

This repository automatically builds the **[unsloth fork](https://github.com/unslothai/llama.cpp)** of llama.cpp — specifically the [`iq1-narrow`](https://github.com/unslothai/llama.cpp/tree/iq1-narrow) branch — with CUDA support for multiple NVIDIA GPU architectures and CUDA versions.

> ⚠️ Unlike the original `ggml-org` tracker, this repo follows a **branch tip** (commit SHA), not upstream GitHub Releases. The unsloth fork does not publish releases, so each build is keyed to the `iq1-narrow` branch's latest commit.

## Why This Repository?

The official llama.cpp repository does not provide pre-built CUDA binaries. This repository fills that gap for the unsloth fork by:

- Building the `iq1-narrow` branch with CUDA support
- Producing **standalone static executables** (`BUILD_SHARED_LIBS=OFF`) — no `.so` dependencies to ship
- Building exactly the unsloth targets: `llama-cli`, `llama-mtmd-cli`, `llama-server`, `llama-gguf-split`
- Supporting a wide range of NVIDIA GPU architectures (compute capability 7.5+)
- Automatically tracking new commits on `iq1-narrow`
- Providing ready-to-use binaries via GitHub releases

## Supported Configurations

### CUDA Versions
- CUDA 12.8

### Host CPU Architectures

Each release publishes one tarball per host CPU architecture:

| Suffix | Linux platform | Typical hosts |
|--------|----------------|---------------|
| `-amd64` | x86_64 | Most desktops, servers, cloud VMs |
| `-arm64` | aarch64 | Grace Hopper, Grace Blackwell, DGX Spark, Ampere Altra |

The CUDA compute capabilities below target the runtime GPU and are the same on both host architectures.

### GPU Architectures

| Compute Capability | GPU Examples |
|-------------------|--------------|
| 7.5 | Tesla T4, RTX 2000 series, Quadro RTX |
| 8.0 | A100 |
| 8.6 | RTX 3000 series |
| 8.9 | RTX 4000 series, L4, L40 |
| 9.0 | H100, H200, GH200 |
| 10.0 | B200, GB200 |
| 12.0 | RTX Pro series, RTX 5000 series |

## Usage

### Download

1. Go to the [Releases](../../releases) page
2. Download the tarball matching your host CPU architecture — `-amd64` for x86_64, `-arm64` for aarch64. Filename format: `llama.cpp-unsloth-<shortsha>-cuda-<cuda>-<arch>.tar.gz`
3. Extract the archive:

```bash
# x86_64 host
tar -xzf llama.cpp-unsloth-<shortsha>-cuda-12.8-amd64.tar.gz
# aarch64 host (e.g. Grace Blackwell, DGX Spark)
tar -xzf llama.cpp-unsloth-<shortsha>-cuda-12.8-arm64.tar.gz
cd cuda-12.8
```

### Run

The extracted directory contains the standalone executables:

```bash
# CLI
./llama-cli --help

# Multimodal CLI
./llama-mtmd-cli --help

# OpenAI-compatible API server
./llama-server --help

# GGUF split / merge utility
./llama-gguf-split --help
```

### Check Version

Each release includes a `VERSION.txt` file with build information (commit SHA, CUDA version, architectures, build date):

```bash
cat VERSION.txt
```

## System Requirements

- NVIDIA GPU with compute capability 7.5 or higher
- NVIDIA driver >= 570.15 (CUDA 12.8)
- Linux x86_64 or aarch64 (Ubuntu 22.04 compatible)

## Build Process

Builds are triggered automatically:
- Daily at 00:00 UTC
- Only if the `iq1-narrow` branch tip has advanced to a commit we have not yet built
- Can be manually triggered (with optional `force_build`) via GitHub Actions

Each build:
1. Resolves the `iq1-narrow` branch tip commit SHA
2. De-duplicates against the tag `unsloth-iq1-narrow-<shortsha>`
3. Clones the unsloth fork at that exact commit
4. Builds with CMake + Ninja inside the CUDA Docker image, calling the shared recipe in `scripts/build.sh`
5. Packages standalone executables per host architecture
6. Creates a GitHub release tagged with the short commit SHA

The build recipe lives in **`scripts/build.sh`** and is the single source of truth shared by both CI and the local test script, so they can never silently drift apart.

## Manual Building

```bash
git clone https://github.com/ai-dock/llama.cpp-cuda
cd llama.cpp-cuda

# Reproduce the CI build locally (requires Docker):
scripts/test-build.sh                       # defaults: CUDA 12.8.1, iq1-narrow
scripts/test-build.sh 12.8.1 iq1-narrow     # explicit

# Or trigger a manual workflow run on GitHub Actions.
```

## License

This repository contains build scripts only. The llama.cpp binaries are subject to the [llama.cpp MIT License](https://github.com/unslothai/llama.cpp/blob/iq1-narrow/LICENSE).

## Links

- **Upstream (unsloth fork)**: https://github.com/unslothai/llama.cpp/tree/iq1-narrow
- **CUDA Toolkit**: https://developer.nvidia.com/cuda-toolkit
- **NVIDIA Driver Downloads**: https://www.nvidia.com/download/index.aspx

## Support

For issues with:
- **Build process or binaries**: Open an issue in this repository
- **llama.cpp functionality**: Open an issue in the [upstream fork](https://github.com/unslothai/llama.cpp/issues)

## Credits

- [llama.cpp](https://github.com/ggerganov/llama.cpp) by Georgi Gerganov and contributors
- [unsloth](https://github.com/unslothai/llama.cpp) fork maintainers
- Built and maintained by [ai-dock](https://github.com/ai-dock)
