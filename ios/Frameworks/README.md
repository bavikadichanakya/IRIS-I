# IRIS-I Native Frameworks Directory

This directory holds Apple XCFrameworks required by `IRIS-I.xcodeproj` and `Package.swift`.

## `llama.xcframework`

### Pinned Upstream Release
* **Release Tag:** `b4500`
* **Commit SHA:** `a133566d34a1dd3693c504786963bf1b7b7d8c0e`
* **Upstream Repository:** `https://github.com/ggml-org/llama.cpp`
* **Target Hardware:** Apple iPhone 17 (Apple A19 SoC, 8 GB RAM)

### Build Instructions (macOS Host with Xcode 15+)
To compile and assemble the native library:
```bash
cd ios
chmod +x build_native_llama.sh
./build_native_llama.sh
```

### Build Specifications
1. **Device Slice (`ios-arm64`):**
   * Architecture: `arm64`
   * Target Platform: `iphoneos17.0+`
   * Metal GPU: `GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON` (Metal bytecode embedded directly in the binary; no separate `.metallib` runtime resolution needed).
   * BLAS: `GGML_BLAS_DEFAULT=ON` (Apple Accelerate framework).
2. **Simulator Slice (`ios-arm64_x86_64-simulator`):**
   * Architectures: `arm64`, `x86_64`
   * Target Platform: `iphonesimulator17.0+`

### Linkage in Xcode Target
In [IRIS-I.xcodeproj/project.pbxproj](file:///a:/iOS%20Assistant/ios/IRIS-I.xcodeproj/project.pbxproj):
* `PBXFrameworksBuildPhase`: Directly links `llama.xcframework` for both `IRIS-I` and `IRIS-ITests`.
* `FRAMEWORK_SEARCH_PATHS`: Includes `$(PROJECT_DIR)/Frameworks` and `$(PROJECT_DIR)/build-apple`.
* `OTHER_LDFLAGS`: Links system frameworks `-framework Metal -framework MetalKit -framework Accelerate`.
* In `Package.swift`: Declares `.binaryTarget(name: "llama", path: "Frameworks/llama.xcframework")` with dependencies in `IRIS_ICore` and `IRIS_ITests`.
