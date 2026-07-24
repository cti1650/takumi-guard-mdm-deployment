# Intune (Windows) セットアップ

Windows 向けに npm / PyPI のレジストリを Takumi Guard（匿名利用）へ設定します。
Intune の **Remediations（検出スクリプト＋修復スクリプト）** で構成します。
署名要求で Remediations が使えない場合は、後述の [Win32アプリ配布](#代替-win32アプリ-intunewin-での配布remediations-が署名でブロックされる場合)で同じスクリプトを流用できます。

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

## 代替: Win32アプリ (.intunewin) での配布（Remediations が署名でブロックされる場合）

Remediations が「コード署名証明書が必要」で実行できない場合、Win32アプリとして
配布すると署名なしで運用できます（インストールコマンドで `-ExecutionPolicy Bypass` を
明示するため）。既存の検出/投入スクリプトをそのまま流用できます。

> **パッケージ化を避けたい/初期投入だけで良いなら Platform script が最小です。**
> Devices > Scripts and remediations > **Platform scripts** で生の `.ps1`
> ([install-takumi-guard.ps1](../intune/remediation/install-takumi-guard.ps1)) を
> アップロードするだけで、`.intunewin` も署名トグルも不要（署名要求が Remediations 由来の場合）。
> 「Run this script using the logged-on credentials = Yes」でユーザーコンテキスト実行します。
> ただし**一度きり実行**（成功までリトライ）で、継続的なドリフト自動修正はありません。
> 継続的な検出→再インストールが必要な場合のみ、以下の Win32 (.intunewin) を使います。

> **前提**: この回避が有効なのは、署名要求が Remediations の
> 「Enforce script signature check」やその組織方針に由来する場合のみです。
> デバイスの実行ポリシーが GPO/Intune で `AllSigned`（MachinePolicy スコープ）に
> 強制されている、または WDAC/AppLocker/Constrained Language Mode が有効な場合は、
> `-ExecutionPolicy Bypass` が上書き・無視されるため Win32 でも回避できません。
> まず対象デバイスで `Get-ExecutionPolicy -List` を確認してください。

### スクリプトのマッピング

| Win32 の構成要素 | 割り当てる内容 |
|---|---|
| 検出ルール | カスタムスクリプト = [detect-takumi-guard.ps1](../intune/detection/detect-takumi-guard.ps1) |
| インストールコマンド | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install-takumi-guard.ps1` |
| アンインストールコマンド | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall-takumi-guard.ps1`（[uninstall-takumi-guard.ps1](../intune/uninstall/uninstall-takumi-guard.ps1) を同梱） |
| インストール動作 | **User**（ユーザーの npm/pip 設定のため） |

### 手順

#### 1. パッケージ化（.intunewin は必須）

Win32アプリは **.intunewin パッケージのアップロードが前提**です。本リポジトリには
手動実行の GitHub Actions ワークフローを用意しているので、ローカルに Windows 環境を
用意せずに `.intunewin` をビルドできます。

**GitHub Actions で手動ビルド（推奨）**

1. GitHub リポジトリ > **Actions** > **build-intunewin** > **Run workflow**
2. 完了後、アーティファクト **`takumi-guard-intunewin`** をダウンロード
   - `install-takumi-guard.intunewin`（アップロードするパッケージ）
   - `intune-config.txt`（下記のインストール/アンインストールコマンド・検出ルールを転記したもの）

ワークフロー: [.github/workflows/build-intunewin.yml](../.github/workflows/build-intunewin.yml) /
ビルドスクリプト: [scripts/build-intunewin.ps1](../scripts/build-intunewin.ps1)
（windows ランナー上で [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) を取得し、
`intune/` 配下の install / uninstall / detection スクリプトを同梱してビルドします）

**ローカル（Windows）でビルドする場合**

```powershell
.\scripts\build-intunewin.ps1   # output\ に .intunewin と intune-config.txt を生成
```

> 2026年1月に「PowerShell スクリプトインストーラー」型（スクリプトをメタデータとして
> 別管理できる機能）が話題になりましたが、(1) アプリ本体の `.intunewin` は依然必要で、
> (2) その後ドキュメントから削除され提供状況が不透明なため、当てにしないでください。

#### 2. アプリの登録

1. Intune admin center > **Apps** > **Windows** > **Add** > **Windows app (Win32)**
2. 生成した `.intunewin` をアップロード
3. **Program**:
   - Install command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install-takumi-guard.ps1`
   - Uninstall command: 上表のリセットコマンド
   - **Install behavior: User**
4. **Requirements**: OS アーキテクチャ / 最低OSバージョンを指定
5. **Detection rules**: **Use a custom detection script** を選び `detect-takumi-guard.ps1` を指定
   - Run script as 32-bit process on 64-bit clients: **No**
   - Enforce script signature check: **No**
6. **Assignments**: 対象グループに **Required** で割り当て

### 検出ルールの挙動（重要）

Win32 のカスタム検出スクリプトは「**終了コード 0 かつ STDOUT に出力あり → インストール済み**」
と判定します。本リポジトリの検出スクリプトはこの規約に合致します:

- 設定済み → `Exit 0` ＋ `COMPLIANT ...` を出力 → **インストール済み** と判定
- 未設定 → `Exit 1` → **未インストール** と判定 → インストールコマンド実行

この仕組みにより、ユーザーがレジストリを戻しても次回の検出評価（IME のチェックイン毎、
概ね24時間間隔）で再インストールされ、**ドリフトが自動修正**されます。

> npm/pip のユーザー設定はアーキテクチャに依存しないため、インストールコマンドは
> 32-bit の `powershell.exe` のままで問題ありません（64-bit を強制する場合は
> `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe` を使用）。

## 動作確認

```powershell
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

---

- [デプロイガイド トップに戻る](deployment-guide.md)
