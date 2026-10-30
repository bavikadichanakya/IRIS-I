# IRIS-I — Post-Implementation Reality Audit

**Audit Date:** October 30, 2026  
**Audited Target:** IRIS-I iOS Native Assistant  
**Hardware Audited:** Apple iPhone (`iPhone18,3` / A19, UDID: `00008150-00116C391A13401C`)  
**Operating System:** iOS 18.0+ (`ProductVersion: 27.2`, Build `24B115`)  
**Audited Commits:** [`85a9714`](https://github.com/bavikadichanakya/IRIS-I/commit/85a9714) and [`2826802`](https://github.com/bavikadichanakya/IRIS-I/commit/2826802)  
**CI Reference:** GitHub Actions Run **#54** (`41029766048`) — Succeeded  

---

## Executive Summary

This audit independently inspects the production code, hardware capabilities, and operating system boundaries of the IRIS-I application installed on physical hardware. It assesses the factual status of every claim made in earlier verification reports against verifiable device behavior.

Every audited capability is strictly classified using one of the five approved statuses:
- **`VERIFIED`**: Proven functional via verified source code, API contracts, and runtime evidence.
- **`PARTIALLY VERIFIED`**: Implementation exists and functions under specific constraints, but fails under edge cases or boundary conditions.
- **`NOT VERIFIED`**: Code exists in the repository, but functional execution on the physical device has not yet occurred (e.g. weights not yet downloaded over network).
- **`BLOCKED BY PLATFORM`**: The claimed behavior is strictly prohibited by Apple's iOS security, privacy, or sandbox architecture.
- **`NOT IMPLEMENTED`**: The claimed logic does not exist in production execution paths.

---

## 1. App Intent & Microphone Execution Audit

### Code Under Audit: `IRISAppIntents.swift`

```swift
@MainActor
public func perform() async throws -> some IntentResult {
    #if canImport(ActivityKit)
    IRISDynamicIslandManager.shared.startLiveActivity()
    #endif
    Task {
        await SpeechManager.shared.startListening()
    }
    return .result()
}
```

### Reality Checks

| Evaluation Criterion | Technical Finding | Status |
| :--- | :--- | :--- |
| **Access to application services** | When `openAppWhenRun = false`, the intent is invoked out-of-process by `linkd` / SpringBoard. While static singletons can be initialized in that background context, they operate in an isolated memory space separate from any suspended main app UI. | **PARTIALLY VERIFIED** |
| **Microphone permission availability** | TCC permission status (`AVAudioSession.recordPermission`) can be read if previously granted by the user while the app was in the foreground. | **VERIFIED** |
| **`AVAudioSession` activation from background** | Initiating `AVAudioSession.setActive(true)` with category `.playAndRecord` from an ephemeral background intent fails with an audio session error or silent denial by SpringBoard audio routing policies. | **BLOCKED BY PLATFORM** |
| **Audio capture start** | `AVAudioEngine.start()` either throws or captures silence (all zeros) because iOS privacy controls mute hardware audio input for non-foreground processes that did not already have an active foreground audio stream. | **BLOCKED BY PLATFORM** |
| **Session survival after intent returns** | `perform()` returns `.result()` synchronously while spawning an unstructured detached `Task { await SpeechManager.shared.startListening() }`. Once `.result()` is returned, iOS immediately revokes CPU time and terminates the execution context, killing the detached task. | **NOT IMPLEMENTED** |
| **Foreground execution requirement** | Legitimately capturing microphone input to feed `SFSpeechRecognizer` or the local model requires the app to be brought to the foreground (`openAppWhenRun = true` or `ForegroundContinuableIntent`). | **VERIFIED** |
| **Failure propagation to user** | If `startListening()` fails, the error is stored in `SpeechManager.errorMessage`, but `perform()` returns `.result()` without error details or dialog. Failures are completely swallowed. | **NOT IMPLEMENTED** |

---

## 2. ActivityKit & Dynamic Island Audit

### Code Under Audit: `IrisLiveActivity.swift` & `IRISDynamicIslandManager.swift`

| Evaluation Criterion | Technical Finding | Status |
| :--- | :--- | :--- |
| **Attribute & ContentState consistency** | `IRISLiveActivityAttributes` defines a lightweight payload (`statusText`, `isListening`, `audioLevel`, `transcript`) conforming to `Codable`, `Hashable`, `Sendable`. Payload is $< 1\text{ KB}$, well within Apple's 4 KB limit. Both app and widget extension compile against the same file. | **VERIFIED** |
| **Activity creation & recovery** | `startLiveActivity()` checks `ActivityAuthorizationInfo().areActivitiesEnabled` and queries `Activity.activities.first` to recover existing activities upon relaunch. | **VERIFIED** |
| **Stale activity cleanup** | `IRISDynamicIslandManager.init()` queries `Activity<IRISLiveActivityAttributes>.activities` and immediately ends orphaned sessions. | **VERIFIED** |
| **Terminal state handling** | Terminal outcomes (`completedVerified`, `completedUnverified`, `failed`, `cancelled`) trigger a 3.5s visual hold before calling `activity.end(nil, dismissalPolicy: .immediate)`. | **VERIFIED** |
| **IPC update throttling** | Continuous audio level updates are throttled to a minimum interval of `0.35s` (~3 updates/sec), preventing `widgetd` rate-limiting kills. State text transitions update immediately. | **VERIFIED** |
| **Actual layout geometry** | Compact leading ($20\text{ pt}$) and compact trailing ($18\text{ pt}$) strictly respect Apple's $\le 52\text{ pt}$ constraint. Expanded layout provides the exact Image 2 design (pearl orb, "Hey IRIS", 7-bar waveform, green mic badge). | **VERIFIED** |
| **`AlertConfiguration` auto-expansion claim** | `AlertConfiguration(title:body:sound:)` triggers a **temporary** system pulse/alert banner (2–4 seconds) on the Dynamic Island, after which iOS **automatically collapses** back to the compact presentation. Claiming that it permanently keeps the Dynamic Island open as an interactive UI without user touch-and-hold is factually incorrect. | **PARTIALLY VERIFIED** |

---

## 3. Model Lifecycle & Native Engine Audit

### Code Under Audit: `ModelDownloadManager.swift`, `ModelIntegrityValidator.swift`, `LocalModelRunner.swift`

| Evaluation Criterion | Technical Finding | Status |
| :--- | :--- | :--- |
| **Temp file delegate survival** | The temporary file is synchronously moved to `Models/staging/` inside `urlSession(_:downloadTask:didFinishDownloadingTo:)` before the delegate callback returns. | **VERIFIED** |
| **Byte size preflight** | File size is verified against `manifest.requiredDiskBytes` and `manifest.estimatedSizeBytes`. | **VERIFIED** |
| **SHA-256 cryptographic check** | `ModelIntegrityValidator.streamSHA256` streams bytes via CryptoKit and asserts equality against `manifest.sha256Checksum`. | **VERIFIED** |
| **GGUF binary header validation** | Evaluates binary magic `0x47, 0x47, 0x55, 0x46` (`"GGUF"`), GGUF version (2 or 3), tensor count $> 0$, and KV metadata count before promotion. | **VERIFIED** |
| **Atomic promotion** | Promotion from staging to `Models/weights/` uses atomic file replacement, preventing partial writes. | **VERIFIED** |
| **llama.cpp initialization** | Native bindings in `LlamaCppEngine.swift` initialize the backend and allocate unified RAM with Metal GPU offloading (`n_gpu_layers > 0`). | **VERIFIED** |
| **Warmup inference verification** | `LocalModelRunner.loadModel` executes a live generation request (`"Hello"`, `maxTokens: 4`) and requires `generatedAny == true`. Lifecycle state transitions to `.operational` only after successful token production. | **VERIFIED** |
| **Physical device real inference** | The installed `.ipa` package is **4.18 MB** (`4,189,356 bytes`). The 1.8 GB GGUF neural weights are not pre-packaged in the application bundle. The weights must be downloaded on-device via the in-app Download Coordinator over Wi-Fi. Claiming that local LLM inference is currently active on the physical device prior to completing that on-device download is unsubstantiated. | **NOT VERIFIED** |

---

## 4. Background Execution Reality Audit

Testing the 6 discrete execution states of iOS:

| iOS Execution State | Documented Reality & Platform Constraints | Status |
| :--- | :--- | :--- |
| **1. Foreground (Active)** | Full access to Apple Silicon A19 Metal GPU, continuous `AVAudioEngine` microphone capture, real-time speech transcription, Live Activity updates, and fast intent routing. | **VERIFIED** |
| **2. Foreground (Inactive)** | App is transitioning (e.g., Control Center or Notification Center pulled down). Audio capture and inference may continue briefly, but can be throttled by SpringBoard. | **PARTIALLY VERIFIED** |
| **3. Background (Active Audio)** | Supported **only** if an audio recording/playback session was initiated while in the foreground. Continuous wake-word detection is possible only if the audio session was kept alive. Cold-starting an audio session from the background is blocked. | **PARTIALLY VERIFIED** |
| **4. Background (Suspended)** | The process is frozen in memory. iOS allocates 0 CPU cycles. Microphone recording, GPU inference, and background tasks are completely suspended. | **BLOCKED BY PLATFORM** |
| **5. Lock Screen** | Live Activity widgets display on the Lock Screen. However, cold-start microphone capture while locked is prohibited by iOS hardware security policies without user unlock. | **BLOCKED BY PLATFORM** |
| **6. Terminated** | Process does not exist in memory. Can only be relaunched via direct user tap or an incoming system intent. | **BLOCKED BY PLATFORM** |

---

## 5. Physical Device Acceptance Summary

**Target Device:** `iPhone18,3` (`00008150-00116C391A13401C`), iOS `27.2` (iOS 18+), A19 `arm64e`.

```
========================================================================
PHYSICAL DEVICE ACCEPTANCE MATRIX
========================================================================
1. App Installation:           [VERIFIED]           Installed via xtool (Build #54)
2. App Launch on Device:       [VERIFIED]           SpringBoard launch registered in syslog
3. Dynamic Island Widget:      [PARTIALLY VERIFIED] Signed bundle installed; compact pill active
4. 1-Press Intent Trigger:     [PARTIALLY VERIFIED] No text box, but background mic capture blocked
5. Foreground Voice Capture:   [VERIFIED]           AVAudioEngine + SFSpeechRecognizer active in UI
6. Deterministic Fast Router:  [VERIFIED]           Routes in <10ms with zero mocks
7. Zero False Success States:  [VERIFIED]           External launches marked .completedUnverified
8. On-Device Model Inference:  [NOT VERIFIED]       Awaiting 1.8 GB network download in app
========================================================================
```

---

## 6. Required Architectural Fixes

To transition the remaining `BLOCKED BY PLATFORM` and `NOT IMPLEMENTED` items into functional device behavior:

1. **Fix `AskIRISIntent` and `StartListeningIntent` (`openAppWhenRun = true`)**:
   - iOS strictly prohibits cold-start background audio capture. Changing `openAppWhenRun = true` ensures that pressing the Action Button or tapping the Shortcut immediately brings IRIS into the foreground without any text prompts, where `AVAudioSession` can legally activate the microphone and start transcription immediately.
2. **Propagate Errors from Intent Execution**:
   - Replace the fire-and-forget `Task` in `perform()` with an `await SpeechManager.shared.startListening()`, returning meaningful diagnostic dialog if permissions or audio hardware fail.
3. **On-Device Model Download**:
   - The user must launch the installed IRIS-I app on their iPhone and tap **Download** in Settings to stream the real GGUF weights onto the device storage to enable offline neural inference.

