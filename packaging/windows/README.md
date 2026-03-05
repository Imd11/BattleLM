# Windows installer

`flutter build windows --release` produces a runnable folder, not a single self-contained `.exe`.

To ship a Windows `.exe` that end users can double-click, build an installer `.exe`:

1. Build the app on Windows:
   `cd flutter_app`
   `flutter build windows --release`
2. Install Inno Setup 6.
3. From the repository root, run:
   `powershell -ExecutionPolicy Bypass -File packaging/windows/build-installer.ps1`
4. The installer will be written to `dist/windows/BattleLM-Setup-<version>.exe`.

What the installer does:

- Copies the full Flutter Windows runtime bundle.
- Installs `battle_lm.exe` and its required DLL/data files.
- Creates Start Menu and optional desktop shortcuts.

Do not ship only `battle_lm.exe`. The app needs the rest of the `Release` directory to run.
