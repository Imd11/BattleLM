# BattleLM - Cross-Platform AI Battle Platform

BattleLM is a cross-platform application that enables AI battles and discussions with multiple AI assistants (Claude, Gemini, Codex, Qwen, Kimi).

## Supported Platforms

| Platform | Status | Build Command |
|----------|--------|---------------|
| macOS | ✅ Ready | `flutter build macos` |
| Windows | 🔄 CI/CD | GitHub Actions |
| Linux | 🔄 CI/CD | GitHub Actions |
| Android | 🔄 CI/CD | GitHub Actions |
| iOS | ✅ Ready | `flutter build ios` |

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

## Architecture

```
BattleLM/
├── flutter_app/              # Flutter UI (cross-platform)
│   ├── lib/                 # Dart code
│   │   ├── core/           # Models & Services
│   │   └── features/       # UI features
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

- Multi-AI conversations and debates
- Group chat with multiple AI participants
- Terminal emulation for AI working directories
- Token usage monitoring
- Remote device connections via WebSocket
- QR code pairing
- Cloudflare tunnel support

## License

MIT
