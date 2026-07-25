# ドキュメント一覧

## セットアップ手順（作業用・コピペで完結）

| MDM | 対象OS | 手順 |
|-----|--------|------|
| **Intune** | Windows | [intune.md](intune.md) |
| **Jamf Pro** | macOS | [jamf-pro.md](jamf-pro.md) |
| **Iru (旧Kandji)** | macOS/Windows | [iru.md](iru.md) |

いずれも URL・トークン・パラメータの入力は不要です（匿名利用の固定値をスクリプトに内蔵）。

## 詳細ドキュメント

| ページ | 内容 |
|--------|------|
| [design.md](design.md) | 設計方針・動作仕様（各設定値の理由、検出仕様、文字コード等） |
| [troubleshooting.md](troubleshooting.md) | 動作確認コマンド・よくある事象・ログの場所 |
| [intune-win32.md](intune-win32.md) | Intune で署名エラーが出る場合の Win32 アプリ配布手順 |

## 段階的展開の目安

1. **Phase 1: 検出のみ** — 検出スクリプト / 拡張属性 / 監査のみ登録し現状把握
2. **Phase 2: パイロット** — 少数のテストデバイスに設定投入を適用
3. **Phase 3: 全体展開** — 対象グループを拡大
