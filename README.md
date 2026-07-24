# Takumi Guard MDM Deployment Scripts

Takumi Guard (GMO Flatt Security) のMDM配布用スクリプト集。
Intune、Jamf Pro、Iru (旧Kandji) で **npm / PyPI** のレジストリ設定を検出・投入できます。

## 対象パッケージマネージャー

匿名利用のため固定値を使用します（トークン・アカウント登録は不要）。

| 対象 | 設定コマンド | レジストリ（固定値） |
|------|--------------|----------------------|
| **npm** | `npm config set registry <URL>` | `https://npm.flatt.tech/` |
| **PyPI (pip)** | `pip config set global.index-url <URL>` | `https://pypi.flatt.tech/simple/` |

> 設定・検出はいずれも各パッケージマネージャーの標準コマンドで行います。
> `.npmrc` / `pip.ini` を直接編集しないため、既存の設定を上書きしません。

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
    └── config-template.yaml  # 設定テンプレート（参照用・編集不要）
```

## 実行コンテキスト（重要）

対象はログオンユーザーの npm/pip 設定です。そのため:

- **Windows (Intune/Iru)**: ログオンユーザーのコンテキストで実行してください
  （Intune の場合は "Run this script using the logged-on credentials" = Yes）。
- **macOS (Jamf/Iru)**: root で実行されますが、スクリプトが自動的にコンソール
  ログイン中のユーザー権限でコマンドを実行します。

npm / pip が未インストールの場合、そのパッケージマネージャーはスキップされます
（設定対象がないため検出上も対象外扱い）。

---

## Intune (Windows)

### 検出スクリプト

`intune/detection/detect-takumi-guard.ps1`

- Exit 0: 設定済み（修復不要）
- Exit 1: 未設定（修復が必要）

### 修復スクリプト

`intune/remediation/install-takumi-guard.ps1`

固定値を使用するため環境変数の設定は不要です。

### 登録手順

1. Microsoft Intune admin center > Devices > Scripts and remediations
2. Create > Detection script: `detect-takumi-guard.ps1`
3. Remediation script: `install-takumi-guard.ps1`
4. Script settings:
   - Run this script using the logged-on credentials: **Yes**
   - Run script in 64-bit PowerShell: Yes

---

## Jamf Pro (macOS)

### 拡張属性

`jamf-pro/extension-attributes/takumi-guard-status.sh`

- Data Type: String
- 出力: "Configured" / "Not Configured" / "Error"

### ポリシースクリプト

`jamf-pro/policies/install-takumi-guard.sh`

固定値を使用するため、ポリシーパラメータ（$4-$6）の設定は不要です。

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

固定値を使用するため環境変数の設定は不要です。

### 登録手順

1. Iru Console > Library > Custom Scripts
2. Add Script > Upload script
3. Blueprint に追加

---

## 段階的展開

### Phase 1: 検出のみ

各MDMの検出スクリプト/拡張属性のみを登録し、現状把握を行う。

### Phase 2: パイロットグループ

少数のテストデバイスに設定投入スクリプトを適用。

### Phase 3: 全体展開

対象グループを拡大して全デバイスに展開。

---

## トラブルシューティング

### ログの確認

- **Windows (Iru)**: `%ProgramData%\Iru\Logs\takumi-guard.log`
- **macOS (Jamf/Iru)**: `/var/log/takumi-guard-*.log`

### 手動テスト

```bash
# npm / PyPI の現在値を確認
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

### 動作確認

```bash
# 悪性パッケージのブロックテスト（403 になれば正常）
npm install <known-malicious-package>
pip install <known-malicious-package>
```

---

## 参考リンク

- [Takumi Guard 公式ドキュメント](https://shisho.dev/docs/ja/t/guard/)
- [Takumi Guard クイックスタート (npm)](https://shisho.dev/docs/ja/t/guard/quickstart/npm/)
- [Takumi Guard クイックスタート (PyPI)](https://shisho.dev/docs/ja/t/guard/quickstart/pypi/)
- [Intune Remediation Scripts](https://learn.microsoft.com/mem/intune/fundamentals/remediations)
- [Jamf Pro Scripts](https://docs.jamf.com/jamf-pro/documentation/Scripts.html)
