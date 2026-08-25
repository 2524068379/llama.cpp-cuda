#!/usr/bin/env bash
#
# Shared llama.cpp CUDA build recipe.
#
# This script is the SINGLE source of truth for how llama.cpp is cloned,
# configured, built and packaged. It is invoked identically by:
#   - CI:  .github/workflows/build-cuda.yml (inside the CUDA Docker image)
#   - Local testing: scripts/test-build.sh   (inside the CUDA Docker image)
#
# It MUST run inside the nvidia/cuda devel container (apt + cmake + nvcc available).
# Keeping the recipe here eliminates the drift between CI and local builds.
#
# Usage (run from /workspace, the repo root, inside the container):
#   scripts/build.sh <output_dir> <architectures> <upstream_repo> <upstream_ref> \
#                   <cuda_version_short> <build_targets> [build_shared_libs]
#
#   output_dir           where to copy the resulting binaries (e.g. binaries/cuda-12.8)
#   architectures        CMAKE_CUDA_ARCHITECTURES value, ';' separated
#   upstream_repo        git URL to clone from
#   upsteram_ref         branch name OR commit SHA to build
#   cuda_version_short   e.g. 12.8 (only used in VERSION.txt)
#   build_targets        space-separated list of cmake targets (e.g. "llama-cli llama-server")
#   build_shared_libs    ON|OFF (default OFF)
set -euo pipefail

OUTPUT_DIR="${1:?output_dir required}"
ARCHITECTURES="${2:?architectures required}"
UPSTREAM_REPO="${3:?upstream_repo required}"
UPSTREAM_REF="${4:?upstream_ref required}"
CUDA_VERSION_SHORT="${5:?cuda_version_short required}"
BUILD_TARGETS="${6:?build_targets required}"
BUILD_SHARED_LIBS="${7:-OFF}"

echo "=== Build configuration ==="
echo "  Output dir:       ${OUTPUT_DIR}"
echo "  Architectures:    ${ARCHITECTURES}"
echo "  Upstream repo:    ${UPSTREAM_REPO}"
echo "  Upstream ref:     ${UPSTREAM_REF}"
echo "  CUDA version:     ${CUDA_VERSION_SHORT}"
echo "  Build targets:    ${BUILD_TARGETS}"
echo "  Shared libs:      ${BUILD_SHARED_LIBS}"
echo ""

echo "=== Installing minimal dependencies ==="
apt-get update -qq
apt-get install -y --no-install-recommends \
    git cmake ninja-build build-essential libssl-dev ca-certificates \
    curl libcurl4-openssl-dev pciutils
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== Cloning upstream ==="
cd /workspace
# Clone the requested ref. --branch accepts both branch names and tags.
git clone --branch "${UPSTREAM_REF}" "${UPSTREAM_REPO}" llama.cpp 2>/dev/null || \
    { git clone "${UPSTREAM_REPO}" llama.cpp && cd llama.cpp && git checkout "${UPSTREAM_REF}" && cd /workspace; }
cd llama.cpp
# If UPSTREAM_REF looks like a commit SHA, pin to it exactly.
if git cat-file -e "${UPSTREAM_REF}^{commit}" 2>/dev/null; then
    git checkout "${UPSTREAM_REF}" 2>/dev/null || true
fi
BUILD_HASH="$(git rev-parse HEAD)"
BUILD_SHORT_HASH="$(git rev-parse --short=7 HEAD)"
echo "Building commit: ${BUILD_HASH} (${BUILD_SHORT_HASH})"

echo "=== Configuring build with Ninja ==="
export LIBRARY_PATH="/usr/local/cuda/lib64/stubs${LIBRARY_PATH:+:$LIBRARY_PATH}"
# Some base images only ship libcuda.so (no .so.1); link it so the build resolves.
ln -sf /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1

cmake -B build -S . \
    -G Ninja \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${ARCHITECTURES}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS="${BUILD_SHARED_LIBS}" \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DCMAKE_EXE_LINKER_FLAGS='-Wl,-rpath-link,/usr/local/cuda/lib64/stubs'

echo "=== Building with Ninja (parallel: all cores) ==="
# shellcheck disable=SC2086  # BUILD_TARGETS is intentionally word-split
cmake --build build --config Release -j"$(nproc)" --target ${BUILD_TARGETS}

echo "=== Copying binaries ==="
cd /workspace
mkdir -p "${OUTPUT_DIR}"
cp -r llama.cpp/build/bin/* "${OUTPUT_DIR}/" 2>/dev/null || true

# Strip executables to reduce size. With BUILD_SHARED_LIBS=OFF everything is a
# standalone executable; with ON we avoid stripping the .so files.
if [ "${BUILD_SHARED_LIBS}" = "OFF" ]; then
    find "${OUTPUT_DIR}/" -type f -executable -exec strip {} \; 2>/dev/null || true
else
    find "${OUTPUT_DIR}/" -type f -executable ! -name "*.so*" -exec strip {} \; 2>/dev/null || true
fi

echo "=== Creating version info ==="
{
    echo "source: ${UPSTREAM_REPO}"
    echo "ref: ${UPSTREAM_REF}"
    echo "commit: ${BUILD_HASH}"
    echo "short_commit: ${BUILD_SHORT_HASH}"
    echo "cuda_version: ${CUDA_VERSION_SHORT}"
    echo "architectures: ${ARCHITECTURES}"
    echo "build_shared_libs: ${BUILD_SHARED_LIBS}"
    echo "build_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "${OUTPUT_DIR}/VERSION.txt"

echo "=== Build complete ==="
ls -lh "${OUTPUT_DIR}/"
