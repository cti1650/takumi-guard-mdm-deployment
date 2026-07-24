# Takumi Guard MDM Deployment Guide

MDM別の詳細な設定手順。

匿名利用のため、以下の固定値を使用します（トークン・環境変数の指定は不要）。

| 対象 | レジストリ（固定値） |
|------|----------------------|
| npm | `https://npm.flatt.tech/` |
| PyPI (pip) | `https://pypi.flatt.tech/simple/` |

いずれのスクリプトも、設定・検出を各パッケージマネージャーの標準コマンド
（`npm config` / `pip config`）で行うため、既存の `.npmrc` / `pip.ini` を
上書きしません。対象はログオンユーザーのユーザー設定です。

---

## Intune 設定手順

### 1. Remediation パッケージの作成

1. Microsoft Intune admin center にログイン
2. **Devices** > **Scripts and remediations** > **Create**
3. 名前: "Takumi Guard Configuration"
4. **Detection script**: `intune/detection/detect-takumi-guard.ps1`
5. **Remediation script**: `intune/remediation/install-takumi-guard.ps1`
6. Script settings:
   - Run script in 64-bit PowerShell: **Yes**
   - Run this script using the logged-on credentials: **Yes**
     （ユーザーの npm/pip 設定を対象とするため必須）

### 2. 割り当て

1. **Assignments** でターゲットグループを選択
2. Schedule: Once / Daily / Hourly (検証時は Once)
3. Deploy

---

## Jamf Pro 設定手順

### 1. 拡張属性の作成

1. **Settings** > **Computer Management** > **Extension Attributes**
2. **New**:
   - Display Name: "Takumi Guard Status"
   - Data Type: String
   - Inventory Display: Extension Attributes
   - Input Type: Script
   - Script: `jamf-pro/extension-attributes/takumi-guard-status.sh` の内容
3. Save

### 2. スクリプトの登録

1. **Settings** > **Computer Management** > **Scripts**
2. **New**:
   - Display Name: "Install Takumi Guard"
   - Script: `jamf-pro/policies/install-takumi-guard.sh` の内容
   - 固定値を使用するため Parameter Labels の設定は不要
3. Save

### 3. Smart Computer Group の作成

1. **Computers** > **Smart Computer Groups** > **New**
2. Criteria:
   - Takumi Guard Status | is | Not Configured
3. Save

### 4. ポリシーの作成

1. **Computers** > **Policies** > **New**
2. General:
   - Display Name: "Configure Takumi Guard"
   - Trigger: Recurring Check-in
   - Execution Frequency: Once per computer
3. Scripts:
   - Add "Install Takumi Guard"（パラメータの指定は不要）
4. Scope:
   - Target: 上記 Smart Computer Group
5. Save

---

## Iru 設定手順

### 1. カスタムスクリプトの登録

#### macOS

1. Iru Console > **Library** > **Custom Scripts**
2. **Add Script**:
   - Name: "Takumi Guard Installer (macOS)"
   - Script: `iru/custom-scripts/install-takumi-guard-macos.sh`
   - Run As: root（スクリプトが自動的にコンソールユーザー権限で設定します）

#### Windows

1. Iru Console > **Library** > **Custom Scripts**
2. **Add Script**:
   - Name: "Takumi Guard Installer (Windows)"
   - Script: `iru/custom-scripts/install-takumi-guard-windows.ps1`
   - Run As: ログオンユーザー（ユーザーの npm/pip 設定を対象とするため）

### 2. 監査スクリプトの登録 (macOS)

1. **Library** > **Audit & Remediation**
2. **Add**:
   - Audit Script: `iru/custom-scripts/detect-takumi-guard.sh`
   - Remediation Script: (上記インストールスクリプトを指定)

### 3. Blueprint への追加

1. **Blueprints** > 対象Blueprint を選択
2. **Library Items** > Add
3. 上記スクリプトを追加
4. Save & Assign

---

## 検証手順

### 1. 検出テスト

各MDMで検出スクリプトを手動実行し、正しく状態が取得できるか確認。

### 2. 設定投入テスト

テストデバイスで設定投入スクリプトを実行し、レジストリが正しく設定されるか確認。

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
