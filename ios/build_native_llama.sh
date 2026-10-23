#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# IRIS-I: Build Native llama.cpp XCFramework for Apple A19 (iPhone 17)
#
# Pinned Upstream Release:
#   Release Tag:  b4500
#   Commit SHA:   a133566d34a1dd3693c504786963bf1b7b7d8c0e
#   Source Repo:  https://github.com/ggml-org/llama.cpp.git
#
# Target Architectures & Slices:
#   - ios-device:  arm64 (Apple A19 Metal GPU acceleration enabled)
#   - ios-sim:     arm64, x86_64 (iOS Simulator)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORKS_DIR="${SCRIPT_DIR}/Frameworks"
BUILD_TEMP_DIR="${SCRIPT_DIR}/.llama_build_tmp"
LLAMA_REVISION="b4500"
LLAMA_COMMIT_SHA="a133566d34a1dd3693c504786963bf1b7b7d8c0e"

echo "=========================================================="
echo " Building llama.cpp XCFramework"
echo " Pinned Tag:        ${LLAMA_REVISION}"
echo " Pinned Commit SHA: ${LLAMA_COMMIT_SHA}"
echo " Target Device:     iPhone 17 (Apple A19 SoC, 8 GB RAM)"
echo "=========================================================="

mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${BUILD_TEMP_DIR}"

cd "${BUILD_TEMP_DIR}"

if [ ! -d "llama.cpp" ]; then
    echo "Cloning official ggml-org/llama.cpp repository..."
    git clone https://github.com/ggml-org/llama.cpp.git
fi

cd llama.cpp

echo "Checking out exact pinned commit: ${LLAMA_COMMIT_SHA}..."
git fetch origin
git checkout "${LLAMA_COMMIT_SHA}"

RESOLVED_SHA=$(git rev-parse HEAD)
if [ "${RESOLVED_SHA}" != "${LLAMA_COMMIT_SHA}" ]; then
    echo "Error: Git checkout mismatch! Expected ${LLAMA_COMMIT_SHA}, got ${RESOLVED_SHA}" >&2
    exit 1
fi
echo "Verified source commit: ${RESOLVED_SHA}"

# Copy the tuned, b4500-compatible build-xcframework script into the repository root
cp "${SCRIPT_DIR}/build-xcframework.sh" ./build-xcframework.sh
chmod +x ./build-xcframework.sh

echo "Configuring environment for Metal GPU compilation..."
export GGML_METAL=ON
export GGML_METAL_EMBED_LIBRARY=ON
export GGML_BLAS_DEFAULT=ON
export IOS_MIN_OS_VERSION=17.0
export MACOS_MIN_OS_VERSION=14.0

echo "Compiling slices: ios-device (arm64 Metal) & ios-sim (arm64/x86_64)..."
./build-xcframework.sh ios-device ios-sim

echo "Installing generated XCFramework to ${FRAMEWORKS_DIR}/llama.xcframework..."
rm -rf "${FRAMEWORKS_DIR}/llama.xcframework"
cp -R build-apple/llama.xcframework "${FRAMEWORKS_DIR}/"

echo "=========================================================="
echo " XCFramework compilation complete!"
echo " Output path: ${FRAMEWORKS_DIR}/llama.xcframework"
echo " Linked slices:"
ls -la "${FRAMEWORKS_DIR}/llama.xcframework"
echo "=========================================================="
