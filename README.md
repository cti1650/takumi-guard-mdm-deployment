# Takumi Guard MDM Deployment Scripts

Takumi Guard (GMO Flatt Security) のMDM配布用スクリプト集。
Intune、Jamf Pro、Iru (旧Kandji) で段階的な検出・設定投入が可能。

## 対応MDM

| MDM | 対象OS | 検出方法 | 設定投入方法 |
|-----|--------|----------|--------------|
| **Intune** | Windows | Remediation Detection Script | Remediation Script |
| **Jamf Pro** | macOS | Extension Attribute | Policy Script |
| **Iru** | macOS/Windows | Audit Script | Custom Script |

## ディレクトリ構成

```
.
├── intune/
│   ├── detection/          # 検出スクリプト
│   └── remediation/        # 修復スクリプト
├── jamf-pro/
│   ├── extension-attributes/  # 拡張属性
│   ├── policies/              # ポリシースクリプト
│   └── profiles/              # 構成プロファイル
├── iru/
│   ├── blueprints/         # ブループリント設定
│   └── custom-scripts/     # カスタムスクリプト
└── common/
    └── config-template.yaml  # 設定テンプレート
```

## セットアップ

### 1. 設定ファイルの準備

```bash
cp common/config-template.yaml common/config.yaml
# config.yaml を編集して組織のRegistry URLを設定
```

### 2. 各MDMへの登録

詳細は `docs/deployment-guide.md` を参照。

---

## Intune (Windows)

### 検出スクリプト

`intune/detection/detect-takumi-guard.ps1`

- Exit 0: 設定済み（修復不要）
- Exit 1: 未設定（修復が必要）

### 修復スクリプト

`intune/remediation/install-takumi-guard.ps1`

#### 環境変数

| 変数名 | 必須 | 説明 |
|--------|------|------|
| `TAKUMI_REGISTRY_URL` | Yes | Takumi Guard Registry URL |
| `TAKUMI_DETECTION_MODE` | No | registry / proxy / both (default: registry) |
| `TAKUMI_CREATE_BACKUP` | No | true / false (default: true) |

### 登録手順

1. Microsoft Intune admin center > Devices > Scripts and remediations
2. Create > Detection script: `detect-takumi-guard.ps1`
3. Remediation script: `install-takumi-guard.ps1`
4. Script settings で環境変数を設定

---

## Jamf Pro (macOS)

### 拡張属性

`jamf-pro/extension-attributes/takumi-guard-status.sh`

- Data Type: String
- 出力: "Configured" / "Not Configured" / "Error"

### ポリシースクリプト

`jamf-pro/policies/install-takumi-guard.sh`

#### パラメータ

| Parameter | 説明 |
|-----------|------|
| $4 | Registry URL (必須) |
| $5 | Install mode: user / global / both (default: user) |
| $6 | Create backup: true / false (default: true) |

### 登録手順

1. **拡張属性**: Jamf Pro > Settings > Computer Management > Extension Attributes > New
2. **スクリプト**: Jamf Pro > Settings > Computer Management > Scripts > New
3. **ポリシー**: Jamf Pro > Computers > Policies > New
   - Trigger: Smart Computer Group (拡張属性でフィルタ)
   - Scripts: 上記スクリプトを追加

---

## Iru (macOS/Windows)

### カスタムスクリプト

- macOS: `iru/custom-scripts/install-takumi-guard-macos.sh`
- Windows: `iru/custom-scripts/install-takumi-guard-windows.ps1`

### 監査スクリプト

- macOS: `iru/custom-scripts/detect-takumi-guard.sh`

#### 環境変数

| 変数名 | 必須 | 説明 |
|--------|------|------|
| `TAKUMI_REGISTRY_URL` | Yes | Takumi Guard Registry URL |
| `TAKUMI_INSTALL_MODE` | No | user / global / both (default: user) |
| `TAKUMI_CREATE_BACKUP` | No | true / false (default: true) |

### 登録手順

1. Iru Console > Library > Custom Scripts
2. Add Script > Upload script
3. Environment Variables で上記変数を設定
4. Blueprint に追加

---

## 段階的展開

### Phase 1: 検出のみ

各MDMの検出スクリプト/拡張属性のみを登録し、現状把握を行う。

### Phase 2: パイロットグループ

少数のテストデバイスに設定投入スクリプトを適用。

### Phase 3: 全体展開

対象グループを拡大して全デバイスに展開。

---

## セキュリティ

- **組織トークン**: `TAKUMI_REGISTRY_URL` には組織トークンを含めて設定
- **環境変数**: 機密情報はMDMの環境変数機能で管理（リポジトリには含めない）
- **バックアップ**: 設定投入前に既存.npmrcをバックアップ

---

## トラブルシューティング

### ログの確認

- **Windows (Intune/Iru)**: `%ProgramData%\Iru\Logs\takumi-guard.log`
- **macOS (Jamf/Iru)**: `/var/log/takumi-guard-*.log`

### 手動テスト

```bash
# macOS
export TAKUMI_REGISTRY_URL="https://registry.takumi.dev/npm/"
./iru/custom-scripts/install-takumi-guard-macos.sh
```

```powershell
# Windows
$env:TAKUMI_REGISTRY_URL = "https://registry.takumi.dev/npm/"
.\iru\custom-scripts\install-takumi-guard-windows.ps1
```

---

## 参考リンク

- [Takumi Guard 公式ドキュメント](https://shisho.dev/docs/ja/t/guard/)
- [Intune Remediation Scripts](https://learn.microsoft.com/mem/intune/fundamentals/remediations)
- [Jamf Pro Scripts](https://docs.jamf.com/jamf-pro/documentation/Scripts.html)
- [Iru Custom Scripts](https://support.iru.dev/)
