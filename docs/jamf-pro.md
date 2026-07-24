# Jamf Pro (macOS) セットアップ

macOS 向けに npm / PyPI のレジストリを Takumi Guard（匿名利用）へ設定します。
**Extension Attribute（状態検出）＋ Policy Script（設定投入）** で構成します。

## 対象ファイル

| 役割 | ファイル |
|------|----------|
| 拡張属性（検出） | [../jamf-pro/extension-attributes/takumi-guard-status.sh](../jamf-pro/extension-attributes/takumi-guard-status.sh) |
| ポリシースクリプト（投入） | [../jamf-pro/policies/install-takumi-guard.sh](../jamf-pro/policies/install-takumi-guard.sh) |

- 拡張属性の出力: `<result>Configured</result>` / `<result>Not Configured</result>` / `<result>Error</result>`
- 設定値（固定・匿名利用）: npm=`https://npm.flatt.tech/` / PyPI=`https://pypi.flatt.tech/simple/`
- 固定値のため **ポリシーパラメータ（$4-$6）の設定は不要**

## 登録手順

### 1. 拡張属性の作成

1. **Settings** > **Computer Management** > **Extension Attributes** > **New**
2. 設定:
   - Display Name: "Takumi Guard Status"
   - Data Type: **String**
   - Input Type: **Script**
   - Script: `takumi-guard-status.sh` の内容を貼り付け
3. Save

### 2. スクリプトの登録

1. **Settings** > **Computer Management** > **Scripts** > **New**
2. Display Name: "Install Takumi Guard"、Script: `install-takumi-guard.sh` の内容を貼り付け
3. Save（Parameter Labels の設定は不要）

### 3. Smart Computer Group の作成

1. **Computers** > **Smart Computer Groups** > **New**
2. Criteria: `Takumi Guard Status | is | Not Configured`
3. Save

### 4. ポリシーの作成

1. **Computers** > **Policies** > **New**
2. General: Display Name "Configure Takumi Guard" / Trigger: Recurring Check-in / Frequency: Once per computer
3. Scripts: "Install Takumi Guard" を追加（パラメータ不要）
4. Scope: 上記 Smart Computer Group
5. Save

## 注意事項

- スクリプトは **root で実行**され、スクリプト内で**コンソールログイン中のユーザー権限**に
  切り替えて npm/pip を設定します（ユーザーの設定を対象とするため）。
- Extension Attribute は「未実行」と「実行したが値なし」を区別できるよう、
  必ず `<result>...</result>` で値を返します。

## 動作確認

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

---

- [デプロイガイド トップに戻る](deployment-guide.md)
