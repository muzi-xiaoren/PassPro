# PassPro

**中文** | [English](README.en.md)

跨平台本地密码管理器。

## 设计要点

- **加密**：SHA-256 派生 + Fernet 对称加密
- **存储**：append-only 行式日志（一行一个操作）+ 内存索引，CRUD 全部 O(1)，启动一次性 replay
- **整理**：放大率达到阈值或手动按钮触发 compaction，把"操作历史"折叠成"最新快照"
- **同步**：可选；支持 GitHub、Gitee、WebDAV / 坚果云，采用 **Primary + Mirror** 模式
  - Primary 是真相源，pull/push 都先走 primary
  - Primary 不可达时自动降级从 Mirror 拉取
  - push 永远先写 Primary，再尽力推 Mirror
- **同步提示**：新增 / 修改 / 删除 操作前后提示"拉取 / 推送"，可在设置里关闭
  - 智能跳过：远端版本与上次一致时自动跳过"拉取"提示
  - "本次会话不再提示" 一键关闭直到下次启动

## 数据存放位置

加密日志文件名固定为 `passwords.log`，位于各平台「应用支持目录」下的 `PassPro/` 子目录中
（由 `path_provider` 的 `getApplicationSupportDirectory()` 决定，路径与包名 `com.example.PassPro` 绑定）：


| 平台      | 实际路径                                                                                                                                            |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS   | `~/Library/Application Support/com.example.PassPro/PassPro/passwords.log`（macOS 关闭沙盒后落在此处；旧沙盒容器内的数据会在首次启动时自动迁移过来） |
| Windows | `%APPDATA%\com.example\PassPro\PassPro\passwords.log`（即 `C:\Users\<用户名>\AppData\Roaming\com.example\PassPro\PassPro\passwords.log`）             |
| Linux   | `~/.local/share/passpro/PassPro/passwords.log`（遵循 `XDG_DATA_HOME`）                                                                              |
| Android | 应用私有目录 `…/files/PassPro/passwords.log`（如 `/data/data/com.example.PassPro/files/PassPro/`，需 root 才能直接访问）                                         |
| iOS     | 应用沙盒 `…/Library/Application Support/PassPro/passwords.log`（通过「文件 App / 设备备份」访问）                                                                 |


> 不确定真实路径时，先启动一次 App 并写入一条数据，再用文件管理器搜索 `passwords.log`。
> 主密钥永不落盘；Token / 应用密码存于系统钥匙串，也不在上述目录里。

## 目录结构

```
PassPro/
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
│   │   ├── webdav_backend.dart   # WebDAV/坚果云实现
│   │   └── sync_manager.dart     # 主备调度 + 状态
│   ├── settings/
│   │   ├── app_settings.dart     # SharedPreferences
│   │   └── secure_credential_store.dart  # Token / 应用密码走 OS Keychain
│   └── ui/
│       ├── master_key_page.dart
│       ├── home_page.dart        # 查询 / 新增 / 列表 三 Tab
│       ├── settings_page.dart
│       ├── sync_prompts.dart
│       └── password_generator.dart
├── test/
│   ├── crypto_compat_test.dart
│   └── merge_test.dart
```

## 准备环境

```bash
# 1. 安装 Flutter（macOS）
brew install --cask flutter
flutter doctor                    # 按提示装齐 Xcode / Android Studio 组件

# 2. 拉依赖
cd PassPro
flutter pub get

# 3. 跑测试
flutter test

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
flutter build macos --release      # build/macos/Build/Products/Release/PassPro.app
```

## 同步配置

PassPro 会把加密日志 `passwords.log` 同步到远程位置。建议至少配置一个
**Primary** 后端；可选再配置一个 **Mirror** 作为备份。

### GitHub

1. 新建一个 **私有仓库**（例：`passpro`）。
2. 创建 Fine-grained token：
  - Repository access：只选择该私有仓库
  - Repository permissions → Contents：Read and write
3. App 设置页填写：
  - Role：Primary
  - Owner：GitHub 用户名
  - Repo：仓库名
  - Branch：`main`
  - File path：`passwords.log`
  - Token：GitHub token

### Gitee

1. 新建一个 **私有仓库**（例：`passpro`）。
2. 创建私人令牌，权限选择 `projects`。
3. App 设置页填写：
  - Role：Mirror（也可作为 Primary）
  - Owner：Gitee 用户名
  - Repo：仓库名
  - Branch：`master`
  - File path：`passwords.log`
  - Token：Gitee 私人令牌

### WebDAV / 坚果云

1. 注册坚果云账号。
2. 在坚果云「账户设置 → 安全选项 → 第三方应用管理」创建应用密码。
3. App 设置页填写：
  - Role：Primary 或 Mirror
  - 用户名：坚果云账号邮箱
  - 服务器地址：`https://dav.jianguoyun.com/dav/`
  - 远程文件路径：`/PassPro/passwords.log`
  - 应用密码：坚果云生成的应用密码

WebDAV 不需要提前创建文件夹或 `passwords.log`，首次推送时 App 会自动创建。

配置完成后，点击「测试连接」确认可用；第一次同步建议先确认本地列表正常，再执行「推送」。

## 安全说明

- 主密钥永远不存盘，只在内存
- Token / 应用密码走 OS Keychain（Android Keystore / Win DPAPI / macOS Keychain）
- 同步到云端的是密文日志；即使 token 泄漏，攻击者拿不到主密钥也无法解密

