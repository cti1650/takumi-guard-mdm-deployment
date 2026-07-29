# Intune Win32アプリ配布（Remediations が署名でブロックされる場合）

Remediations の実行時に「コード署名証明書が必要」と表示される場合の代替手順です。
Win32アプリとして配布すると、インストールコマンドで `-ExecutionPolicy Bypass` を明示するため署名なしで運用できます。スクリプトは Remediations 用と同じものを流用します。

## 事前確認（重要）

この回避が有効なのは、署名要求が Remediations の「Enforce script signature check」やその組織方針に由来する場合のみです。まず対象デバイスで確認してください:

```powershell
Get-ExecutionPolicy -List
```

- `MachinePolicy` / `UserPolicy` が `Undefined` → **この手順で回避できます**
- `MachinePolicy` が `AllSigned` 等（GPO/Intune 強制）、または WDAC / AppLocker / Constrained Language Mode が有効 → `-ExecutionPolicy Bypass` が無効化されるため **Win32 でも回避できません**（スクリプト署名の導入が必要）

> **もっと軽い代替**: 初期投入だけで良い（ドリフト自動修正が不要）なら、
> Devices > Scripts and remediations > **Platform scripts** に
> [install-takumi-guard.ps1](../intune/remediation/install-takumi-guard.ps1) をそのままアップロードするのが最小です
> （パッケージ化・署名とも不要、logged-on credentials = Yes で実行）。
> 継続的な検出→再設定が必要な場合のみ、以下の Win32 手順を使います。

## 1. .intunewin パッケージを取得

GitHub Actions でビルドします（ローカルに Windows 環境は不要）:

1. GitHub リポジトリ > **Actions** > **build-intunewin** > **Run workflow**
2. 完了後、アーティファクト **`takumi-guard-intunewin`** をダウンロード
   - `install-takumi-guard.intunewin` … 手順2でアップロードするパッケージ
   - `intune-config.txt` … 手順2で貼り付けるコマンド類の転記メモ

ローカル（Windows）でビルドする場合: `.\scripts\build-intunewin.ps1`（`output\` に生成）

## 2. アプリを登録

Intune admin center > **Apps** > **Windows** > **Add** > **Windows app (Win32)**

| 設定項目 | 値 |
|------|------|
### Select app package file

| 設定項目 | 値 |
|------|------|
| App package file | `install-takumi-guard.intunewin` をアップロード |

### App information

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard Configuration` |
| Description | `npm / PyPI のパッケージ取得を Takumi Guard 経由に設定し、悪性パッケージをブロックします。` |
| Publisher | 自組織名（例: `IT 部門`） |
| App Version | `1.0`（任意） |
| Category | 未設定のままで可 |
| Show this as a featured app in the Company Portal | `No` |
| Information URL | `https://shisho.dev/docs/ja/t/guard/`（任意） |
| Logo | 未設定のままで可 |

> Name / Description / Publisher は必須項目です。それ以外は空欄のままでも登録できます。

### Program

| 設定項目 | 値 |
|------|------|
| Install command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install-takumi-guard.ps1` |
| Uninstall command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall-takumi-guard.ps1` |
| Install behavior | **User** ← 必須 |
| Device restart behavior | `No specific action` |
| Return codes | 既定のまま（`0` = Success） |

### Requirements

| 設定項目 | 値 |
|------|------|
| Operating system architecture | `x64`（Arm64 端末があれば併せてチェック） |
| Minimum operating system | `Windows 10 1607` |

### Detection rules

| 設定項目 | 値 |
|------|------|
| Rules format | `Use a custom detection script` |
| Script file | [detect-takumi-guard.ps1](../intune/detection/detect-takumi-guard.ps1) |
| Run script as 32-bit process on 64-bit clients | `No` |
| Enforce script signature check and run script silently | `No` |

### Assignments

| 設定項目 | 値 |
|------|------|
| Required | 対象グループを追加 |

## 検出ルールの挙動

Win32 のカスタム検出スクリプトは「終了コード 0 かつ STDOUT に出力あり → インストール済み」と判定します。本リポジトリの検出スクリプトはこの規約に合致しており:

- 設定済み → `Exit 0` + 出力あり → インストール済みと判定
- 未設定 → `Exit 1` → 未インストールと判定 → インストールコマンド実行

ユーザーが設定を戻しても次回の検出評価（IME チェックイン毎、概ね24時間間隔）で再設定される、**ドリフト自動修正**として機能します。

## 補足

- npm/pip のユーザー設定はアーキテクチャ非依存のため、インストールコマンドは 32-bit `powershell.exe` のままで問題ありません（64-bit を強制する場合は `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe`）
- パッケージ構成: [build-intunewin.yml](../.github/workflows/build-intunewin.yml) が [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) で `intune/` 配下の install / uninstall / detection スクリプトを同梱してビルドします
- 「PowerShell スクリプトインストーラー」型（2026年1月に話題になった、スクリプトをメタデータとして別管理できる機能）は、アプリ本体の `.intunewin` が依然必要なうえ、その後ドキュメントから削除され提供状況が不透明なため、当てにしないでください

---

- [Intune セットアップ手順に戻る](intune.md)
- [ドキュメント一覧に戻る](deployment-guide.md)
