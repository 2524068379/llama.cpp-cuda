#!/bin/bash
#
# Local test build for llama.cpp CUDA binaries.
#
# This script is a THIN wrapper: it only resolves CUDA version -> docker tag /
# architectures and then delegates the actual build to scripts/build.sh (the
# single shared recipe). CI uses exactly the same recipe, so a local test build
# reproduces what the workflow produces.
#
# Usage:
#   scripts/test-build.sh [cuda_version] [upstream_ref]
#
#   cuda_version  12.8.1 (default) | 12.9.1 | 13.0.1
#   upstream_ref  iq1-narrow (default) | <branch> | <commit SHA>
#
# Defaults target the unsloth fork (env vars below can override).

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---- Upstream fork (defaults match CI workflow env) ----
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/unslothai/llama.cpp}"
UPSTREAM_REF="${2:-iq1-narrow}"

# ---- Build knobs (match the unsloth quick-start recipe) ----
# NOTE: These default values MUST stay in sync with the CI workflow at
# .github/workflows/build-cuda.yml (see UPSTREAM_BRANCH, build_targets,
# BUILD_SHARED_LIBS, and architectures there). Changing one without the
# other will cause local test builds to diverge from release builds.
BUILD_TARGETS="${BUILD_TARGETS:-llama-cli llama-mtmd-cli llama-server llama-gguf-split}"
BUILD_SHARED_LIBS="${BUILD_SHARED_LIBS:-OFF}"
# ARCHITECTURES does NOT vary by CUDA version — define it once here.
# Keep this in sync with the workflow matrix 'architectures' value.
ARCHITECTURES="${ARCHITECTURES:-75-virtual;80-virtual;86-virtual;89-virtual;90-virtual;100-virtual;120-virtual}"

CUDA_VERSION="${1:-12.8.1}"

echo -e "${GREEN}llama.cpp CUDA Build Test${NC}"
echo "================================"
echo "Upstream repo:  ${UPSTREAM_REPO}"
echo "Upstream ref:   ${UPSTREAM_REF}"
echo "CUDA Version:   ${CUDA_VERSION}"
echo "Targets:        ${BUILD_TARGETS}"
echo "Shared libs:    ${BUILD_SHARED_LIBS}"
echo ""

# Validate CUDA version and set parameters
case "$CUDA_VERSION" in
    12.8.1)
        CUDA_TAG="12.8.1-cudnn-devel-ubuntu22.04"
        CUDA_VERSION_SHORT="12.8"
        ;;
    12.9.1)
        CUDA_TAG="12.9.1-cudnn-devel-ubuntu22.04"
        CUDA_VERSION_SHORT="12.9"
        ;;
    13.0.1)
        CUDA_TAG="13.0.1-cudnn-devel-ubuntu22.04"
        CUDA_VERSION_SHORT="13.0"
        ;;
    *)
        echo -e "${RED}Error: Unsupported CUDA version $CUDA_VERSION${NC}"
        echo "Supported versions: 12.8.1, 12.9.1, 13.0.1"
        exit 1
        ;;
esac

echo -e "${YELLOW}Building with:${NC}"
echo "  Docker Image:   nvidia/cuda:$CUDA_TAG"
echo "  Architectures:  $ARCHITECTURES"
echo ""

# Clean previous builds
rm -rf binaries test-build
mkdir -p "binaries/cuda-${CUDA_VERSION_SHORT}"

OUTPUT_DIR="/workspace/binaries/cuda-${CUDA_VERSION_SHORT}"

echo -e "${GREEN}Starting Docker build (delegating to scripts/build.sh)...${NC}"
docker run --rm -v "$PWD":/workspace \
    nvidia/cuda:"$CUDA_TAG" \
    bash /workspace/scripts/build.sh \
        "${OUTPUT_DIR}" \
        "${ARCHITECTURES}" \
        "${UPSTREAM_REPO}" \
        "${UPSTREAM_REF}" \
        "${CUDA_VERSION_SHORT}" \
        "${BUILD_TARGETS}" \
        "${BUILD_SHARED_LIBS}"

# Create tarball
echo ""
echo -e "${GREEN}Creating tarball...${NC}"
cd binaries
SHORT_SHA=$(grep -E '^short_commit:' "cuda-${CUDA_VERSION_SHORT}/VERSION.txt" | awk '{print $2}')
TARBALL="llama.cpp-unsloth-${SHORT_SHA:-unknown}-cuda-${CUDA_VERSION}.tar.gz"
tar -czf "$TARBALL" "cuda-${CUDA_VERSION_SHORT}"
cd ..

# Show results
echo ""
echo -e "${GREEN}✓ Build successful!${NC}"
echo ""
echo "Binaries location: binaries/cuda-${CUDA_VERSION_SHORT}/"
echo "Tarball:           binaries/${TARBALL}"
echo ""
echo "Built binaries:"
ls -lh "binaries/cuda-${CUDA_VERSION_SHORT}/"

# Clean up cloned source (build.sh leaves it at /workspace/llama.cpp inside
# the container, which maps to ./llama.cpp here)
rm -rf llama.cpp

echo ""
echo -e "${GREEN}Test build complete!${NC}"
