# Iru (旧Kandji / macOS・Windows) セットアップ

macOS / Windows 向けに npm / PyPI のレジストリを Takumi Guard（匿名利用）へ設定します。
**Custom Script（設定投入）＋ Audit Script（検出）** で構成します。

> **補足**: 2025年10月に Kandji は **Iru** へ改称し、Apple 専用から Windows / Android にも
> 対応するクロスプラットフォーム基盤へ拡張されました。Windows 対応は比較的新しいため、
> Windows カスタムスクリプトの詳細な操作手順は導入時に Iru 公式ドキュメントで最終確認することを推奨します。

## 対象ファイル

| 役割 | OS | ファイル |
|------|----|----------|
| 設定投入 | macOS | [../iru/custom-scripts/install-takumi-guard-macos.sh](../iru/custom-scripts/install-takumi-guard-macos.sh) |
| 設定投入 | Windows | [../iru/custom-scripts/install-takumi-guard-windows.ps1](../iru/custom-scripts/install-takumi-guard-windows.ps1) |
| 監査（検出） | macOS | [../iru/custom-scripts/detect-takumi-guard.sh](../iru/custom-scripts/detect-takumi-guard.sh) |

- 設定値（固定・匿名利用）: npm=`https://npm.flatt.tech/` / PyPI=`https://pypi.flatt.tech/simple/`
- 固定値のため **環境変数の設定は不要**

## 登録手順

### 1. カスタムスクリプトの登録

#### macOS

1. Iru Console > **Library** > **Custom Scripts** > **Add Script**
2. Name: "Takumi Guard Installer (macOS)"、Script: `install-takumi-guard-macos.sh`
3. Run As: **root**（スクリプトが自動的にコンソールユーザー権限で設定します）

#### Windows

1. Iru Console > **Library** > **Custom Scripts** > **Add Script**
2. Name: "Takumi Guard Installer (Windows)"、Script: `install-takumi-guard-windows.ps1`
3. Run As: **ログオンユーザー**（ユーザーの npm/pip 設定を対象とするため）

### 2. 監査スクリプトの登録 (macOS)

1. **Library** > **Audit & Remediation** > **Add**
2. Audit Script: `detect-takumi-guard.sh`
3. Remediation Script: 上記インストールスクリプトを指定

### 3. Blueprint への追加

1. **Blueprints** > 対象 Blueprint を選択
2. **Library Items** > Add で上記スクリプトを追加
3. Save & Assign

## 注意事項

- **macOS**: root 実行 → スクリプト内でコンソールユーザー権限に切替えて npm/pip を設定。
- **Windows**: 文字コードは Windows PowerShell 5.1 を想定し、ps1 は ASCII コメント＋
  UTF-8（BOM なし）で保存しています。ログオンユーザーコンテキストで実行してください。
- 未導入のパッケージマネージャーは自動的にスキップされます。

## 動作確認

```bash
# macOS
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

---

- [デプロイガイド トップに戻る](deployment-guide.md)
