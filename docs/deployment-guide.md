# Takumi Guard MDM Deployment Guide

MDM別の詳細な設定手順は、以下の媒体別ドキュメントを参照してください。

| MDM | 対象OS | ドキュメント |
|-----|--------|--------------|
| **Intune** | Windows | [intune.md](intune.md) |
| **Jamf Pro** | macOS | [jamf-pro.md](jamf-pro.md) |
| **Iru (旧Kandji)** | macOS/Windows | [iru.md](iru.md) |

## 共通事項（固定値・匿名利用）

いずれの MDM でも、以下の固定値を使用します（トークン・環境変数の指定は不要）。

| 対象 | レジストリ（固定値） |
|------|----------------------|
| npm | `https://npm.flatt.tech/` |
| PyPI (pip / pip3) | `https://pypi.flatt.tech/simple/` |

- 設定・検出は各パッケージマネージャーの標準コマンド（`npm config` / `pip config`）で行い、
  `.npmrc` / `pip.ini` を直接編集しないため既存設定を上書きしません。
- 対象は**ログオンユーザーのユーザー設定**です。
- npm / pip が未導入の環境は、そのパッケージマネージャーをスキップします。
- pip と pip3 はユーザー設定ファイルを共有するため、どちらか一方の設定で両方に反映されます。

## 検証手順

### 1. 検出テスト

各 MDM の検出スクリプトを手動実行し、状態が正しく取得できるか確認します。

### 2. 設定投入テスト

```bash
# 確認コマンド (macOS/Linux)
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

```powershell
# 確認コマンド (Windows)
npm config get registry
pip config get global.index-url
```

### 3. Takumi Guard 動作確認

```bash
# 悪性パッケージのブロックテスト（403エラーになれば正常）
npm install <known-malicious-package>
pip install <known-malicious-package>
```

## 参考リンク

- [Takumi Guard クイックスタート (npm)](https://shisho.dev/docs/ja/t/guard/quickstart/npm/)
- [Takumi Guard クイックスタート (PyPI)](https://shisho.dev/docs/ja/t/guard/quickstart/pypi/)
