#!/usr/bin/env python3
"""从旧 Python 版 password_manager 迁移数据到 Passman Pro (PassPro)。

旧格式（Markdown，每条三行一组）：
    ### website
    - **Username**: username
    - **Password**: encrypted_password
新格式（JSON Lines，每行一个操作）：
    {"op":"ADD","id":"...","ts":1715000000,"w":"github.com","u":"alice","p":"<fernet-ct>"}

加密算法完全相同（SHA-256 派生 + Fernet），所以密文字段 p 直接复制、无需解密重加密。

用法：
    # 预览（不写文件），默认读 ~/Downloads/passwords.md
    python3 tools/migrate_from_old.py --dry-run

    # 生成新日志到当前目录的 passwords.log
    python3 tools/migrate_from_old.py

    # 指定输入/输出
    python3 tools/migrate_from_old.py --in /path/passwords.md --out /path/passwords.log

生成后，把 passwords.log 放到 App 的数据目录（见脚本结尾打印的各平台路径），
然后启动 App 即可。建议在 App 从未写入过数据时迁移，避免覆盖。
"""

import argparse
import json
import os
import secrets
import sys
import time

DEFAULT_IN = os.path.expanduser("~/Downloads/passwords.md")
DEFAULT_OUT = "passwords.log"


def parse_markdown(text):
    """解析 Markdown 格式，每条三行一组：

        ### website
        - **Username**: username
        - **Password**: encrypted_password

    返回 (website, username, password) 列表，username 可为空。
    """
    entries = []
    website = None
    username = ""
    password = None

    def flush():
        nonlocal website, username, password
        if website and password:
            entries.append((website, username, password))
        website = None
        username = ""
        password = None

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("###"):
            flush()
            website = line.lstrip("#").strip()
        elif line.startswith("- **Username**:"):
            username = line.split(":", 1)[1].strip()
        elif line.startswith("- **Password**:"):
            password = line.split(":", 1)[1].strip()

    flush()
    return entries


def make_id(index):
    """生成单设备内唯一的 record id（与 Dart 端格式无关，只需唯一）。"""
    return f"mig-{index:05d}-{secrets.token_hex(6)}"


def convert(in_path, dedup=True):
    if not os.path.exists(in_path):
        sys.exit(f"找不到输入文件: {in_path}")

    now = int(time.time())  # unix 秒（UTC），新格式 ts 用秒
    records = []
    seen = set()
    skipped = 0
    suspicious = 0

    with open(in_path, "r", encoding="utf-8") as f:
        entries = parse_markdown(f.read())

    for website, username, password in entries:
        if dedup:
            key = (website, username, password)
            if key in seen:
                continue
            seen.add(key)

        # Fernet token 以 'gAAAAA' 开头，给个温和提醒（不阻断）
        if not password.startswith("gAAAAA"):
            suspicious += 1

        records.append({
            "op": "ADD",
            "id": make_id(len(records)),
            "ts": now,
            "w": website,
            "u": username,
            "p": password,
        })

    return records, skipped, suspicious


def app_data_paths():
    return [
        ("macOS",   "~/Library/Application Support/PassPro/passwords.log"
                    "   （若 path_provider 嵌套了 bundle id，实际为"
                    " ~/Library/Application Support/<bundle-id>/PassPro/passwords.log）"),
        ("Windows", r"%APPDATA%\PassPro\passwords.log"),
        ("Linux",   "~/.local/share/PassPro/passwords.log"),
        ("Android", "app 私有目录（不可直接访问；可用 adb 或在设备上导入）"),
    ]


def main():
    ap = argparse.ArgumentParser(description="迁移旧 Python 密码数据到 PassPro")
    ap.add_argument("--in", dest="in_path", default=DEFAULT_IN,
                    help=f"旧 Markdown 路径（默认 {DEFAULT_IN}）")
    ap.add_argument("--out", dest="out_path", default=DEFAULT_OUT,
                    help=f"输出 JSON Lines 路径（默认 ./{DEFAULT_OUT}）")
    ap.add_argument("--dry-run", action="store_true", help="只预览，不写文件")
    ap.add_argument("--no-dedup", action="store_true",
                    help="不去重（默认去除完全相同的 website/username/password）")
    args = ap.parse_args()

    records, skipped, suspicious = convert(args.in_path, dedup=not args.no_dedup)

    print(f"读取: {args.in_path}")
    print(f"转换出 {len(records)} 条记录"
          + (f"，跳过 {skipped} 行格式不符" if skipped else "")
          + (f"，{suspicious} 条密文不像 Fernet token（请核对）" if suspicious else ""))

    if args.dry_run:
        print("\n--- 预览前 3 行 ---")
        for r in records[:3]:
            print(json.dumps(r, ensure_ascii=False))
        print("\n(--dry-run，未写文件)")
        return

    with open(args.out_path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"已写入: {os.path.abspath(args.out_path)}")

    print("\n把它放到 App 数据目录的 passwords.log（App 未写入过数据时最稳妥）：")
    for name, path in app_data_paths():
        print(f"  - {name}: {path}")


if __name__ == "__main__":
    main()
