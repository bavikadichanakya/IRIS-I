# IRIS-I Native Frameworks Directory

This directory holds binary Apple XCFrameworks required by `IRIS-I.xcodeproj` and `Package.swift`.

## `llama.xcframework` (Pinned: `b4500`)

The native runtime is built from upstream `ggml-org/llama.cpp` pinned at release tag `b4500`.

### Build Instructions (macOS Host with Xcode 15+)

To compile and install the framework:
```bash
cd ios
chmod +x build_native_llama.sh
./build_native_llama.sh
```

This compiles:
1. `iphoneos` slice: `arm64` with Metal GPU acceleration for Apple A19 (iPhone 17).
2. `iphonesimulator` slice: `arm64`/`x86_64` for Xcode iOS Simulator.
3. Embedded Metal Shaders (`GGML_METAL_EMBED_LIBRARY=ON`).

The resulting `llama.xcframework` is placed directly at `ios/Frameworks/llama.xcframework` and referenced by the Xcode project via `FRAMEWORK_SEARCH_PATHS`.
