# BattleLM (Flutter) - Cross-Platform Desktop UI

This folder contains the cross-platform **Flutter desktop UI** for BattleLM.  
Goal: ship the **same UI/UX** on Windows/Linux/macOS.

## Supported Platforms

| Platform | Status | Build Command |
|----------|--------|---------------|
| macOS | ✅ UI | `flutter build macos` |
| Windows | ✅ UI | `flutter build windows` |
| Linux | ✅ UI | `flutter build linux` |
| Android | ✅ UI | `flutter build apk` |
| iOS | ✅ UI | `flutter build ios` |

Notes:
- Current implementation is a **standalone local demo** (no remote Mac dependency).
- AI execution/bridges are a follow-up phase; UI is built to match the mac design first.

## Development Setup

### Prerequisites

- Flutter 3.24.0+
- Rust 1.70+
- Xcode (for macOS/iOS builds)

### Install Dependencies

```bash
cd flutter_app
flutter pub get

# For Rust core
cd src
cargo build
```

### Build Commands

```bash
# Install deps
cd flutter_app
flutter pub get

# macOS
flutter build macos

# iOS
flutter build ios

# Android (requires Android SDK)
flutter build apk --release

# Windows (requires Windows host)
flutter build windows

# Linux (requires Linux host)
flutter build linux
```

## CI/CD Builds

The project includes GitHub Actions workflows for automated builds:

- **Windows**: Built on `windows-latest` runner
- **Linux**: Built on `ubuntu-latest` runner with Linux dependencies
- **Android**: Built on `ubuntu-latest` with Android SDK

See `.github/workflows/build.yml` for details.

## UI Architecture (current)

```
BattleLM/
├── flutter_app/              # Flutter UI (cross-platform)
│   ├── lib/                 # Dart code
│   │   ├── app/            # App state + app shell
│   │   ├── core/           # Models & Storage
│   │   └── features/       # Sidebar + Chat UI
│   ├── src/                # Rust core
│   │   ├── process_manager/
│   │   ├── websocket/
│   │   ├── token_monitor/
│   │   └── storage/
│   └── .github/workflows/  # CI/CD
├── BattleLM/                # Original macOS app
├── BattleLM-iOS/           # Original iOS app
└── bridge/                 # Node.js AI bridges
```

## Features

- Sidebar: AI instances + group chats
- 1:1 AI chat and group chat UI
- Typing indicator and streaming message simulation
- Local storage for instances/chats

## License

MIT
