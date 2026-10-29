# IRIS-I: Standalone On-Device iOS Assistant & Gateway

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: iOS 17+](https://img.shields.io/badge/Platform-iOS%2017%2B-lightgrey.svg)](ios/)
[![Engine: llama.cpp Metal](https://img.shields.io/badge/Engine-Metal%20Accelerated-orange.svg)](ios/IRIS-I/Core/Engine/)
[![Architecture: Standalone ReAct](https://img.shields.io/badge/Architecture-100%25%20On--Device-success.svg)](ios/IRIS-I/Core/Agent/)

**IRIS-I** is a high-performance, 100% on-device AI assistant engineered for Apple Silicon (iPhone 17 / Apple A19) running iOS 17+.

It combines **Metal-accelerated local LLM inference** (`llama.cpp`), a sub-10ms **Deterministic Fast Intent Router**, and an autonomous multi-step **ReAct reasoning loop** with native iOS integrations.

---

## 🏛️ System Architecture

```
                    ┌───────────────────────────────────────────────────────────┐
                    │                      USER INTERACTION                     │
                    │   • Hands-Free Voice ("Hey Iris")                         │
                    │   • Real-Time Interactive SwiftUI Chat (AssistantChatView)│
                    │   • Hardware Action Button & Siri Shortcuts Integration   │
                    └─────────────────────────────┬─────────────────────────────┘
                                                  │
                                                  ▼
                    ┌───────────────────────────────────────────────────────────┐
                    │               TIER 1: FAST INTENT ROUTER                  │
                    │   • <10ms Deterministic Regex & Pattern Dispatcher        │
                    │   • Real-Time System Time & Date Queries                  │
                    │   • Battery Status & Hardware Telemetry (Jetsam Footprint)│
                    └─────────────────────────────┬─────────────────────────────┘
                                                  │ (if complex/unmatched)
                                                  ▼
                    ┌───────────────────────────────────────────────────────────┐
                    │          TIER 2: ON-DEVICE ReAct REASONING LOOP           │
                    │   • Metal GPU-Accelerated Local LLM (Apple A19)           │
                    │   • Supported Profiles: Qwen 2.5 3B, SmolLM3, Llama 3.2   │
                    │   • Model-Agnostic Formatters (ChatMLPromptFormatter)     │
                    │   • Resilient Fallback Parser (Doubled Braces, JSON Fences)│
                    └─────────────────────────────┬─────────────────────────────┘
                                                  │
                                                  ▼
                    ┌───────────────────────────────────────────────────────────┐
                    │          CRYPTOGRAPHIC POLICY & CONFIRMATION GATE         │
                    │   • Permission Taxonomy: PUBLIC | PROTECTED | SENSITIVE   │
                    │   • Single-Use Confirmation Tickets (HMAC-SHA256 Digest)  │
                    │   • Replay Prevention & Argument Tampering Protection     │
                    └─────────────────────────────┬─────────────────────────────┘
                                                  │
                                                  ▼
                    ┌───────────────────────────────────────────────────────────┐
                    │              STANDALONE ON-DEVICE TOOL SUITE              │
                    │   • SystemInfoTool: System clock, battery, RAM footprint  │
                    │   • WebSearchTool: Live news, AI updates via direct HTTPS │
                    │   • MailTool: Inbox search (e.g. OpenAI) & mailto drafts  │
                    │   • MessagingTool: Direct SMS/iMessage composer handoff   │
                    │   • EventKitTool: Reminders & Calendar (iOS 16 & 17+)     │
                    │   • ShortcutsTool: Apple Shortcuts multi-app automation   │
                    │   • AppOpenerTool: Verified public URL scheme launcher    │
                    └───────────────────────────────────────────────────────────┘
```

---

## 🚀 Core Assistant Capabilities

### 1. Instant System Intelligence (<10ms)
- **Time & Date**: Instantaneous clock queries directly from the Darwin system clock without waiting for LLM generation.
- **Hardware Telemetry**: Real-time monitoring of application physical footprint (`task_vm_info.phys_footprint` Jetsam budget), device thermal state (`ProcessInfo.thermalState`), and battery status.

### 2. Live Web & AI News
- **`WebSearchTool`**: Fetches real-time information and the latest AI developments over HTTPS. Eliminates model knowledge cutoff limitations.

### 3. Inbox & Communications
- **`MailTool`**: Scans inbox for emails from specific senders (e.g. *"Check if there is an email from OpenAI"*), extracts snippets, and drafts new messages.
- **`MessagingTool`**: Composes SMS and iMessages via verified `sms:` scheme handoffs.

### 4. Apple Reminders & Calendar (iOS 16 & iOS 17+)
- **`EventKitTool`**: Creates and queries Apple Reminders and Calendar events. Features full runtime compatibility with iOS 17's granular permissions (`requestFullAccessToReminders`, `requestFullAccessToEvents`).

### 5. Multi-App Siri Shortcuts Integration
- **`ShortcutsTool`**: Dispatches to user-defined Apple Shortcuts (`shortcuts://run-shortcut?name=...`) to read or write data across third-party apps like Notes, Spotify, and WhatsApp.

---

## 📁 Repository Structure

```
A:\iOS Assistant\
├── ios\
│   ├── Package.swift                 # SwiftPM package defining IRIS_ICore & IRIS_ITests
│   ├── IRIS-I\
│   │   ├── App\
│   │   │   ├── IRIS_IApp.swift       # SwiftUI App lifecycle entrypoint
│   │   │   └── ContentView.swift     # TabView hosting Assistant and Diagnostic views
│   │   ├── Views\
│   │   │   ├── AssistantChatView.swift# Interactive chat, quick chips, token streaming
│   │   │   ├── DiagnosticConsoleView.swift # Hardware monitors & benchmark runner
│   │   │   └── TelemetryBarView.swift# Live memory and thermal gauges
│   │   ├── Core\
│   │   │   ├── Agent\
│   │   │   │   ├── Dispatch\         # FastIntentRouter (<10ms) & ReActOrchestrator
│   │   │   │   ├── Formatters\       # ChatMLPromptFormatter, Llama3PromptFormatter
│   │   │   │   ├── Parser\           # ToolCallParser (normalizes {{}}, strips fences)
│   │   │   │   ├── Protocols\        # IRISAgentTool, ToolExecutionOutcome, schemas
│   │   │   │   ├── Registry\         # ToolRegistry, AppLaunchRegistry
│   │   │   │   ├── Security\         # PermissionManager, ConfirmationTicket (CryptoKit)
│   │   │   │   └── Tools\            # SystemInfo, WebSearch, Mail, Messaging, EventKit, Shortcuts, AppOpener
│   │   │   ├── Engine\               # LlamaCppEngine, LocalModelRunner, MockModelEngine
│   │   │   ├── ModelManager\         # ModelCatalog, ModelManifest, Storage & Integrity
│   │   │   └── System\               # HardwareTelemetry (Darwin task_info), ThermalState
│   │   └── Resources\
│   │       ├── Info.plist            # Usage descriptions for EventKit, mic, speech, schemes
│   │       └── IRIS-I.entitlements   # iOS entitlements configuration
│   └── Tests\IRIS_ITests\            # Comprehensive XCTest suite
```

---

## 📄 License
IRIS-I is distributed under the [MIT License](LICENSE).
