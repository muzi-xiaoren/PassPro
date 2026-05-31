# Passman Pro (PassPro)

[中文](README.md) | **English**

A cross-platform local password manager, rewritten from the `password_manager` project (Python/Tkinter → Flutter).

![Build](https://github.com/muzi-xiaoren/PassPro/actions/workflows/build.yml/badge.svg)

## Download / CI builds

Every push to `main` triggers GitHub Actions to build four platforms in parallel.
The artifacts can be downloaded from the **Artifacts** section at the bottom of each
[Actions run page](https://github.com/muzi-xiaoren/PassPro/actions):

| Artifact | File | Notes |
|---|---|---|
| Android | `PassPro-Android-APK` (app-release.apk) | Sideload directly |
| Windows | `PassPro-Windows.zip` | Unzip and run `passman_pro.exe` |
| macOS | `PassPro-macOS.zip` | Unzip to get the `.app` (first launch: right-click → Open to bypass Gatekeeper) |
| iOS | `PassPro-iOS-unsigned.zip` | **Unsigned** — must be re-signed with an Apple developer certificate before installing on a real device |

> You can also trigger a build manually via **Run workflow** on the Actions page.

## Design highlights

- **Encryption algorithm unchanged**: still SHA-256 derivation + Fernet symmetric encryption, **100% compatible with ciphertext produced by the old Python version**
- **Storage**: append-only line-based log (one operation per line) + in-memory index, all CRUD is O(1), one-time replay on startup
- **Compaction**: triggered when the amplification ratio hits a threshold or by a manual button, folding "operation history" into a "latest snapshot"
- **Sync**: optional; dual backends GitHub + Gitee, **Primary + Mirror (A2 failover)** mode
  - Primary is the source of truth; both pull/push go to primary first
  - When primary is unreachable, automatically falls back to pulling from the mirror
  - push always writes to Primary first, then best-effort pushes to the Mirror
- **Sync prompts**: before/after add / edit / delete operations, prompt to "pull / push" (can be disabled in settings)
  - Smart skip: automatically skips the "pull" prompt when the remote sha matches last time
  - "Don't prompt again this session" — one click to silence until next launch

## Platforms

| Platform | Supported | Notes |
|---|---|---|
| Android | ✅ | `flutter build apk` |
| Windows | ✅ | `flutter build windows` |
| macOS | ✅ | `flutter build macos` |
| Linux | ✅ (bonus) | `flutter build linux` |
| iOS | not prioritized | code runs, but no release polish yet |

## Directory structure

```
passman_pro/
├── lib/
│   ├── main.dart                 # entry point
│   ├── app_state.dart            # global state + master key
│   ├── crypto/
│   │   └── fernet_crypto.dart    # Fernet-compatible implementation
│   ├── models/
│   │   └── password_entry.dart   # PasswordEntry + LogRecord
│   ├── storage/
│   │   ├── log_store.dart        # on-disk log read/write
│   │   ├── memory_index.dart     # in-memory index + keyword search
│   │   ├── vault_repository.dart # CRUD API (the only entry point for the UI)
│   │   ├── compactor.dart        # compaction
│   │   └── conflict_merger.dart  # row-level union merge
│   ├── sync/
│   │   ├── sync_backend.dart     # abstract interface
│   │   ├── git_backend.dart      # shared GitHub/Gitee implementation
│   │   └── sync_manager.dart     # primary/mirror scheduling + state
│   ├── settings/
│   │   ├── app_settings.dart     # SharedPreferences
│   │   └── secure_credential_store.dart  # PAT goes through the OS Keychain
│   └── ui/
│       ├── master_key_page.dart
│       ├── home_page.dart        # Query / Add / List — three tabs
│       ├── settings_page.dart
│       ├── sync_prompts.dart
│       └── password_generator.dart
├── test/
│   ├── crypto_compat_test.dart   # ⭐ verifies it can decrypt old Python ciphertext
│   └── merge_test.dart
└── tools/
    └── verify_with_python.py     # reverse-verification script
```

## Setup

```bash
# 1. Install Flutter (macOS)
brew install --cask flutter
flutter doctor                    # follow prompts to install Xcode / Android Studio components

# 2. Fetch dependencies
cd passman_pro
flutter pub get

# 3. Run tests (the critical compatibility test)
flutter test test/crypto_compat_test.dart

# 4. Run locally
flutter run -d macos              # desktop debugging
flutter run -d <android-device>   # device debugging
```

## Build

```bash
# Android APK
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk

# Windows
flutter build windows --release    # build/windows/x64/runner/Release/

# macOS
flutter build macos --release      # build/macos/Build/Products/Release/passman_pro.app
```

## Data migration (from the old Python version)

The old data lives at `~/password_person/passwords.txt`, one record per line in the format
`website,username,encrypted_password`. The new log format is different (JSON Lines), but the
**encryption algorithm is identical**, so the ciphertext field is copied directly — no need to
decrypt and re-encrypt. A one-shot migration script is ready: `tools/migrate_from_old.py`.

```bash
# Preview (does not write a file); reads ~/password_person/passwords.txt by default
python3 tools/migrate_from_old.py --dry-run

# Generate the new log (defaults to ./passwords.log in the current directory); auto-dedups identical entries
python3 tools/migrate_from_old.py

# Specify input / output
python3 tools/migrate_from_old.py --in /path/old.txt --out /path/passwords.log
```

After generating `passwords.log`, place it in the App's data directory (best done when the App has
never written any data, to avoid overwriting).

New log location:
- macOS: `~/Library/Application Support/PassPro/passwords.log`
  (path_provider may nest the bundle id on macOS, so the actual path could be
  `~/Library/Application Support/<bundle-id>/PassPro/passwords.log`; launch the App once before
  migrating to confirm the real path)
- Windows: `%APPDATA%\PassPro\passwords.log`
- Linux: `~/.local/share/PassPro/passwords.log`
- Android: app private directory (not directly accessible)

## Sync configuration (GitHub + Gitee)

1. Create a **private repository** on GitHub / Gitee (e.g. `my-passwords-vault`)
2. GitHub: Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
   - Repository access: Only `my-passwords-vault`
   - Permissions: Contents → Read and write
3. Gitee: Settings → Private tokens → select the `projects` scope
4. In the App's settings page: fill in owner/repo/branch/file path + PAT for each, and mark the role (Primary / Mirror)
5. Click "Test connection" to confirm it works

## Security notes

- The master key is never written to disk — it lives only in memory
- The PAT goes through the OS Keychain (Android Keystore / Win DPAPI / macOS Keychain)
- What gets synced to the cloud is the ciphertext log; even if the token leaks, an attacker without the master key cannot decrypt it
- **First-version limitation**: the website / username fields are **plaintext** in the log (for compatibility with old files); if you use a private GitHub repo, the repo admin can see the list of sites you have visited. This is a known trade-off; the second phase will add optional "full-field encryption"
