# Jamf Pro セットアップ手順 (macOS)

拡張属性（検出）とポリシー（設定投入）を登録します。**貼り付ける値はすべて下表のとおり**です。URL・トークン・パラメータ（$4-$6）の入力は不要です。

## 1. 拡張属性を作成

**Settings** > **Computer Management** > **Extension Attributes** > **New**

| 設定項目 | 値 |
|------|------|
| Display Name | `Takumi Guard Status` |
| Data Type | `String` |
| Inventory Display | `Extension Attributes` |
| Input Type | `Script` |
| Script | [takumi-guard-status.sh](../jamf-pro/extension-attributes/takumi-guard-status.sh) の内容を貼り付け |

## 2. スクリプトを登録

**Settings** > **Computer Management** > **Scripts** > **New**

| 設定項目 | 値 |
|------|------|
| Display Name | `Install Takumi Guard` |
| Script | [install-takumi-guard.sh](../jamf-pro/policies/install-takumi-guard.sh) の内容を貼り付け |
| Parameter Labels | 設定不要 |

## 3. Smart Computer Group を作成

**Computers** > **Smart Computer Groups** > **New**

| 設定項目 | 値 |
|------|------|
| Display Name | `Takumi Guard - Not Configured` |
| Criteria | `Takumi Guard Status` / `is` / `Not Configured` |

## 4. ポリシーを作成

**Computers** > **Policies** > **New**

| 設定項目 | 値 |
|------|------|
| Display Name | `Configure Takumi Guard` |
| Trigger | `Recurring Check-in` |
| Execution Frequency | `Ongoing` ← 必須 |
| Scripts | `Install Takumi Guard` を追加（パラメータ入力は不要） |
| Maintenance | `Update Inventory` を追加 |
| Scope | `Takumi Guard - Not Configured`（手順3のグループ） |

**Save** で完了。

> `Ongoing` + Smart Group スコープの組み合わせで、設定が戻されたデバイスも自動修正されます（`Once per computer` だと一度成功したデバイスで二度と再実行されません）。`Update Inventory` により設定直後に拡張属性が更新され、スコープから即座に離脱します。

## 5. 完了確認（対象デバイスで実行）

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

インベントリ上は拡張属性 `Takumi Guard Status` が `Configured` になれば成功です
（`Configured (npm only)` 等の部分適合値の意味は [設計方針](design.md#検出仕様) 参照）。

## 6. 解除（アンインストール）する場合

対象から外すデバイスの設定を元に戻すには、解除スクリプトをポリシーとして実行します。

| 設定項目 | 値 |
|------|------|
| Scripts > New | [uninstall-takumi-guard.sh](../jamf-pro/policies/uninstall-takumi-guard.sh) の内容を `Uninstall Takumi Guard` として登録 |
| Policy | 上記スクリプトを追加し、解除対象グループにスコープして実行 |

---

- うまく動かない場合 → [トラブルシューティング](troubleshooting.md)
- 各設定値の理由・動作の仕組み → [設計方針・動作仕様](design.md)
- [ドキュメント一覧に戻る](deployment-guide.md)
