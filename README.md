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

## MDM別セットアップ

各MDMの検出スクリプト・設定投入スクリプトと詳細な登録手順は、媒体別ドキュメントを参照してください。

| MDM | 対象OS | ドキュメント | 主なファイル |
|-----|--------|--------------|--------------|
| **Intune** | Windows | [docs/intune.md](docs/intune.md) | [detect](intune/detection/detect-takumi-guard.ps1) / [install](intune/remediation/install-takumi-guard.ps1) |
| **Jamf Pro** | macOS | [docs/jamf-pro.md](docs/jamf-pro.md) | [status](jamf-pro/extension-attributes/takumi-guard-status.sh) / [install](jamf-pro/policies/install-takumi-guard.sh) |
| **Iru (旧Kandji)** | macOS/Windows | [docs/iru.md](docs/iru.md) | [detect](iru/custom-scripts/detect-takumi-guard.sh) / [macOS](iru/custom-scripts/install-takumi-guard-macos.sh) / [Windows](iru/custom-scripts/install-takumi-guard-windows.ps1) |

共通事項・検証手順は [docs/deployment-guide.md](docs/deployment-guide.md) を参照。

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
