# Intune (Windows) セットアップ

Windows 向けに npm / PyPI のレジストリを Takumi Guard（匿名利用）へ設定します。
Intune の **Remediations（検出スクリプト＋修復スクリプト）** で構成します。

## 対象ファイル

| 役割 | ファイル |
|------|----------|
| 検出スクリプト | [../intune/detection/detect-takumi-guard.ps1](../intune/detection/detect-takumi-guard.ps1) |
| 修復スクリプト | [../intune/remediation/install-takumi-guard.ps1](../intune/remediation/install-takumi-guard.ps1) |

- 検出: `Exit 0` = 設定済み（修復不要） / `Exit 1` = 未設定（修復が必要）
- 設定値（固定・匿名利用）: npm=`https://npm.flatt.tech/` / PyPI=`https://pypi.flatt.tech/simple/`
- 設定・検出は `npm config` / `pip config` コマンドで行い、既存設定は上書きしません

## 登録手順

1. Microsoft Intune admin center > **Devices** > **Scripts and remediations**
2. **Create** で新規作成（名前例: "Takumi Guard Configuration"）
3. **Detection script**: `detect-takumi-guard.ps1` をアップロード
4. **Remediation script**: `install-takumi-guard.ps1` をアップロード
5. Script settings:
   - **Run this script using the logged-on credentials: Yes**（必須）
   - Run script in 64-bit PowerShell: **Yes**
   - Enforce script signature check: **No**
6. **Assignments** で対象グループを選択、スケジュール（検証時は Once）を設定して展開

## 注意事項

### 実行コンテキスト（logged-on credentials = Yes が必須）

Microsoft は多くの修復で SYSTEM コンテキストを推奨していますが、本スクリプトは
**ログオンユーザーの npm/pip 設定**を対象にするため、必ず
「Run this script using the logged-on credentials = Yes」で実行してください。
SYSTEM 実行では対象ユーザーの設定になりません。

対象ユーザーの PATH に npm / pip が通っている必要があります
（未導入のパッケージマネージャーは自動的にスキップされます）。

### 文字コード（Windows PowerShell 5.1）

Intune の実行エンジンは **Windows PowerShell 5.1** です。BOM なし UTF-8 に日本語を
含めると 5.1 がレガシーコードページ (CP932) として解釈し、コメントが文字化けします。
本リポジトリの ps1 は、この問題を避けるためコメントを ASCII（英語）に統一し、
**UTF-8（BOM なし）** で保存しています（Intune 推奨エンコード）。

## 動作確認

```powershell
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

---

- [デプロイガイド トップに戻る](deployment-guide.md)
