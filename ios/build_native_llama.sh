#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# IRIS-I: Build Native llama.cpp XCFramework for Apple A19 (iPhone 17)
# Pinned to Release Tag: b4500
# Target Slices:
#   - iOS Device (arm64, Metal GPU accelerated)
#   - iOS Simulator (arm64, x86_64)
#   - macOS (arm64 Apple Silicon)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORKS_DIR="${SCRIPT_DIR}/Frameworks"
BUILD_TEMP_DIR="${SCRIPT_DIR}/.llama_build_tmp"
LLAMA_REVISION="b4500"

echo "=========================================================="
echo " Building llama.cpp ${LLAMA_REVISION} XCFramework with Metal"
echo " Target Hardware: iPhone 17 (Apple A19 SoC, 8 GB RAM)"
echo "=========================================================="

mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${BUILD_TEMP_DIR}"

cd "${BUILD_TEMP_DIR}"

if [ ! -d "llama.cpp" ]; then
    echo "Cloning official ggml-org/llama.cpp at tag ${LLAMA_REVISION}..."
    git clone --branch "${LLAMA_REVISION}" --depth 1 https://github.com/ggml-org/llama.cpp.git
else
    echo "Using existing llama.cpp source clone..."
fi

cd llama.cpp

echo "Configuring environment for Metal GPU compilation..."
export GGML_METAL=ON
export GGML_METAL_EMBED_LIBRARY=ON
export GGML_BLAS_DEFAULT=ON
export IOS_MIN_OS_VERSION=17.0
export MACOS_MIN_OS_VERSION=14.0

# Build iOS device and simulator slices
if [ -f "./build-xcframework.sh" ]; then
    echo "Executing ./build-xcframework.sh ios-device ios-sim..."
    ./build-xcframework.sh ios-device ios-sim
elif [ -f "${SCRIPT_DIR}/build-xcframework.sh" ]; then
    echo "Executing ${SCRIPT_DIR}/build-xcframework.sh ios-device ios-sim..."
    "${SCRIPT_DIR}/build-xcframework.sh" ios-device ios-sim
else
    echo "Error: build-xcframework.sh not found!"
    exit 1
fi

echo "Copying generated XCFramework to ${FRAMEWORKS_DIR}/llama.xcframework..."
rm -rf "${FRAMEWORKS_DIR}/llama.xcframework"
cp -R build-apple/llama.xcframework "${FRAMEWORKS_DIR}/"

echo "=========================================================="
echo " Successfully built and installed llama.xcframework!"
echo " Location: ${FRAMEWORKS_DIR}/llama.xcframework"
echo "=========================================================="
