# Iru セットアップ手順 (macOS / Windows)

カスタムスクリプト（設定投入）と監査スクリプト（検出）を登録します。**貼り付ける値はすべて下表のとおり**です。URL・トークン・環境変数の入力は不要です。

## 1. カスタムスクリプトを登録

Iru Console > **Library** > **Custom Scripts** > **Add Script**

### macOS

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard Installer (macOS)` |
| Script | [install-takumi-guard-macos.sh](../iru/custom-scripts/install-takumi-guard-macos.sh) の内容を貼り付け |
| Run As | `root` |

### Windows

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard Installer (Windows)` |
| Script | [install-takumi-guard-windows.ps1](../iru/custom-scripts/install-takumi-guard-windows.ps1) の内容を貼り付け |
| Run As | ログオンユーザー |

## 2. 監査スクリプトを登録 (macOS)

**Library** > **Audit & Remediation** > **Add**

| 設定項目 | 値 |
|------|------|
| Audit Script | [detect-takumi-guard.sh](../iru/custom-scripts/detect-takumi-guard.sh) の内容を貼り付け |
| Remediation Script | `Takumi Guard Installer (macOS)`（手順1のスクリプト） |

## 3. Blueprint に追加

1. **Blueprints** > 対象 Blueprint を選択
2. **Library Items** > **Add** で上記アイテムを追加
3. **Save & Assign**

## 4. 完了確認（対象デバイスで実行）

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

---

- うまく動かない場合 → [トラブルシューティング](troubleshooting.md)
- 各設定値の理由・動作の仕組み → [設計方針・動作仕様](design.md)
- [ドキュメント一覧に戻る](deployment-guide.md)
