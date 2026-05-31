# Passman Pro (PassPro)

跨平台本地密码管理器，重构自 `password_manager` 项目（Python/Tkinter → Flutter）。

![Build](https://github.com/muzi-xiaoren/PassPro/actions/workflows/build.yml/badge.svg)

## 下载 / 自动构建

每次推送到 `main` 都会通过 GitHub Actions 并行构建四个平台，产物可在
[Actions 运行页面](https://github.com/muzi-xiaoren/PassPro/actions) 底部的 **Artifacts** 下载：

| 产物 | 文件 | 说明 |
|---|---|---|
| Android | `PassPro-Android-APK`（app-release.apk） | 可直接侧载安装 |
| Windows | `PassPro-Windows.zip` | 解压后运行 `passman_pro.exe` |
| macOS | `PassPro-macOS.zip` | 解压得到 `.app`（首次打开需右键→打开绕过 Gatekeeper） |
| iOS | `PassPro-iOS-unsigned.zip` | **未签名**，需 Apple 开发者证书重新签名后才能装真机 |

> 也可在 Actions 页面点 **Run workflow** 手动触发构建。

## 设计要点

- **核心加密算法不变**：仍是 SHA-256 派生 + Fernet 对称加密，**100% 兼容旧 Python 版本生成的密文**
- **存储**：append-only 行式日志（一行一个操作）+ 内存索引，CRUD 全部 O(1)，启动一次性 replay
- **整理**：放大率达到阈值或手动按钮触发 compaction，把"操作历史"折叠成"最新快照"
- **同步**：可选；GitHub + Gitee 双后端，**Primary + Mirror（A2 故障切换）** 模式
  - Primary 是真相源，pull/push 都先走 primary
  - Primary 不可达时自动降级从 Mirror 拉取
  - push 永远先写 Primary，再尽力推 Mirror
- **同步提示**：新增 / 修改 / 删除 操作前后提示"拉取 / 推送"，可在设置里关闭
  - 智能跳过：远端 sha 与上次一致时自动跳过"拉取"提示
  - "本次会话不再提示" 一键关闭直到下次启动

## 平台

| 平台 | 支持 | 备注 |
|---|---|---|
| Android | ✅ | `flutter build apk` |
| Windows | ✅ | `flutter build windows` |
| macOS | ✅ | `flutter build macos` |
| Linux | ✅（顺带） | `flutter build linux` |
| iOS | 暂不优先 | 代码可跑，但未做发版打磨 |

## 目录结构

```
passman_pro/
├── lib/
│   ├── main.dart                 # 入口
│   ├── app_state.dart            # 全局状态 + 主密钥
│   ├── crypto/
│   │   └── fernet_crypto.dart    # Fernet 兼容实现
│   ├── models/
│   │   └── password_entry.dart   # PasswordEntry + LogRecord
│   ├── storage/
│   │   ├── log_store.dart        # 磁盘日志读写
│   │   ├── memory_index.dart     # 内存索引 + 关键词搜索
│   │   ├── vault_repository.dart # CRUD API（UI 唯一入口）
│   │   ├── compactor.dart        # 压实
│   │   └── conflict_merger.dart  # 行级 union 合并
│   ├── sync/
│   │   ├── sync_backend.dart     # 抽象接口
│   │   ├── git_backend.dart      # GitHub/Gitee 共用实现
│   │   └── sync_manager.dart     # 主备调度 + 状态
│   ├── settings/
│   │   ├── app_settings.dart     # SharedPreferences
│   │   └── secure_credential_store.dart  # PAT 走 OS Keychain
│   └── ui/
│       ├── master_key_page.dart
│       ├── home_page.dart        # 查询 / 新增 / 列表 三 Tab
│       ├── settings_page.dart
│       ├── sync_prompts.dart
│       └── password_generator.dart
├── test/
│   ├── crypto_compat_test.dart   # ⭐ 验证能解开 Python 旧密文
│   └── merge_test.dart
└── tools/
    └── verify_with_python.py     # 反向验证脚本
```

## 准备环境

```bash
# 1. 安装 Flutter（macOS）
brew install --cask flutter
flutter doctor                    # 按提示装齐 Xcode / Android Studio 组件

# 2. 拉依赖
cd passman_pro
flutter pub get

# 3. 跑测试（最关键的兼容性测试）
flutter test test/crypto_compat_test.dart

# 4. 本机运行
flutter run -d macos              # 桌面调试
flutter run -d <android-device>   # 真机调试
```

## 打包

```bash
# Android APK
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk

# Windows
flutter build windows --release    # build/windows/x64/runner/Release/

# macOS
flutter build macos --release      # build/macos/Build/Products/Release/passman_pro.app
```

## 数据迁移（从旧 Python 版本）

旧版数据在 `~/password_person/passwords.txt`，每行格式 `website,username,encrypted_password`。
新版日志格式不同（JSON Lines），但 **加密算法完全相同**，密文字段直接复制即可，
无需解密重加密。一次性迁移脚本已就绪：`tools/migrate_from_old.py`。

```bash
# 预览（不写文件），默认读 ~/password_person/passwords.txt
python3 tools/migrate_from_old.py --dry-run

# 生成新日志（默认输出当前目录 ./passwords.log），自动去重完全相同的条目
python3 tools/migrate_from_old.py

# 指定输入 / 输出
python3 tools/migrate_from_old.py --in /path/old.txt --out /path/passwords.log
```

生成 `passwords.log` 后，放到 App 数据目录（建议在 App 从未写入数据时操作，避免覆盖）。

新版日志位置：
- macOS: `~/Library/Application Support/PassPro/passwords.log`
  （path_provider 在 macOS 上可能嵌套 bundle id，实际可能是
  `~/Library/Application Support/<bundle-id>/PassPro/passwords.log`，迁移前先启动一次 App 确认真实路径）
- Windows: `%APPDATA%\PassPro\passwords.log`
- Linux: `~/.local/share/PassPro/passwords.log`
- Android: app 私有目录（不可直接访问）

## 同步配置（GitHub + Gitee）

1. 去 GitHub / Gitee 创建一个 **私有仓库**（例：`my-passwords-vault`）
2. GitHub：Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
   - Repository access: Only `my-passwords-vault`
   - Permissions: Contents → Read and write
3. Gitee：设置 → 私人令牌 → 选 `projects` 权限
4. App 设置页：分别填入 owner/repo/branch/file path + PAT，标记角色 (Primary / Mirror)
5. 点 "测试连接" 确认配通

## 安全说明

- 主密钥永远不存盘，只在内存
- PAT 走 OS Keychain（Android Keystore / Win DPAPI / macOS Keychain）
- 同步到云端的是密文日志；即使 token 泄漏，攻击者拿不到主密钥也无法解密
- **第一版限制**：website / username 字段在日志里是**明文**（兼容旧文件）；如果用 GitHub 私有仓库，仓库管理员能看到你访问过的网站列表。这是已知折衷，第二阶段会加可选的"全字段加密"
