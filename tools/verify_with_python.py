#!/usr/bin/env python3
"""与旧 Python password_manager 加解密兼容性的反向验证工具。

用法：
    python3 verify_with_python.py decrypt <master_password> <fernet_ciphertext>
    python3 verify_with_python.py gen-vectors <master_password>

前置：pip install cryptography
"""

import base64
import hashlib
import sys

try:
    from cryptography.fernet import Fernet
except ImportError:
    sys.exit('请先安装：pip install cryptography')


def generate_key(master_password: str) -> bytes:
    h = hashlib.sha256(master_password.encode('utf-8')).digest()
    return base64.urlsafe_b64encode(h[:32])


def cmd_decrypt(master: str, ct: str) -> None:
    f = Fernet(generate_key(master))
    print(f.decrypt(ct.encode()).decode())


def cmd_gen_vectors(master: str) -> None:
    """生成几条测试向量，便于贴到 Dart 测试里。"""
    f = Fernet(generate_key(master))
    print(f'master: {master!r}')
    print(f'key_sha256_hex: {hashlib.sha256(master.encode()).hexdigest()}')
    for plain in ['p@ssw0rd', 'hello', 'github_token_abc']:
        ct = f.encrypt(plain.encode()).decode()
        print(f'  {plain!r} -> {ct}')


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    op = sys.argv[1]
    if op == 'decrypt':
        cmd_decrypt(sys.argv[2], sys.argv[3])
    elif op == 'gen-vectors':
        cmd_gen_vectors(sys.argv[2])
    else:
        sys.exit(f'未知命令: {op}')
