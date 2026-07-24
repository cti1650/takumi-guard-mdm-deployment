# Takumi Guard MDM Deployment Guide

MDM別の詳細な設定手順。

## Intune 設定手順

### 1. 環境変数の準備

Intune スクリプト設定で以下の環境変数を設定:

```
TAKUMI_REGISTRY_URL=https://registry.takumi.dev/npm/<YOUR_ORG_TOKEN>/
```

### 2. Remediation パッケージの作成

1. Microsoft Intune admin center にログイン
2. **Devices** > **Scripts and remediations** > **Create**
3. 名前: "Takumi Guard Configuration"
4. **Detection script**: `intune/detection/detect-takumi-guard.ps1`
5. **Remediation script**: `intune/remediation/install-takumi-guard.ps1`
6. Script settings:
   - Run script in 64-bit PowerShell: Yes
   - Run this script using the logged-on credentials: No (SYSTEM権限)

### 3. 割り当て

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
   - Parameter Labels:
     - Parameter 4: Registry URL
     - Parameter 5: Install Mode
     - Parameter 6: Create Backup
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
   - Add "Install Takumi Guard"
   - Parameter Values:
     - $4: `https://registry.takumi.dev/npm/<YOUR_ORG_TOKEN>/`
     - $5: `user`
     - $6: `true`
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
   - Run As: root
3. **Environment Variables**:
   ```
   TAKUMI_REGISTRY_URL=https://registry.takumi.dev/npm/<YOUR_ORG_TOKEN>/
   TAKUMI_INSTALL_MODE=user
   TAKUMI_CREATE_BACKUP=true
   ```

#### Windows

1. Iru Console > **Library** > **Custom Scripts**
2. **Add Script**:
   - Name: "Takumi Guard Installer (Windows)"
   - Script: `iru/custom-scripts/install-takumi-guard-windows.ps1`
   - Run As: SYSTEM
3. **Environment Variables**: 同上

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

テストデバイスで設定投入スクリプトを実行し、.npmrc が正しく設定されるか確認。

```bash
# 確認コマンド (macOS/Linux)
cat ~/.npmrc
npm config get registry
```

```powershell
# 確認コマンド (Windows)
Get-Content $env:USERPROFILE\.npmrc
npm config get registry
```

### 3. Takumi Guard 動作確認

```bash
# 悪性パッケージのブロックテスト
npm install <known-malicious-package>
# 403エラーになれば正常
```
