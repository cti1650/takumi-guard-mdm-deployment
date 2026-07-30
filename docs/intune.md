# Intune セットアップ手順 (Windows)

Remediations に検出・修復スクリプトを登録します。**貼り付ける値はすべて下表のとおり**です。URL やトークンの入力は不要です。

## 1. スクリプトを開く

| 用途 | ファイル（内容をそのまま使用） |
|------|------|
| 検出 | [detect-takumi-guard.ps1](../intune/detection/detect-takumi-guard.ps1) |
| 修復 | [install-takumi-guard.ps1](../intune/remediation/install-takumi-guard.ps1) |
| 検出 (WSL・任意) | [detect-takumi-guard-wsl.ps1](../intune/detection/detect-takumi-guard-wsl.ps1) |
| 修復 (WSL・任意) | [install-takumi-guard-wsl.ps1](../intune/remediation/install-takumi-guard-wsl.ps1) |

## 2. Remediation を作成

[Microsoft Intune admin center](https://intune.microsoft.com/) > **Devices** > **Scripts and remediations** > **Create**

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard Configuration` |
| Description | `npm / PyPI のパッケージ取得を Takumi Guard 経由に設定します。`（任意） |
| Publisher | 既定のまま（自分の名前が入ります・任意） |
| Detection script file | `detect-takumi-guard.ps1` をアップロード |
| Remediation script file | `install-takumi-guard.ps1` をアップロード |
| Run this script using the logged-on credentials | **Yes** ← 必須 |
| Enforce script signature check | **No** |
| Run script in 64-bit PowerShell | **Yes** |

## 3. 割り当て

| 設定項目 | 値 |
|------|------|
| Assignments | 対象グループを選択 |
| Schedule | 検証時: `Once` / 本番: `Daily` |

**Create** で完了。

## 4. 完了確認（対象デバイスで実行）

```powershell
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

## 5. WSL も保護する場合（任意・2つ目の Remediation）

WSL 内の npm / pip は Windows 側の設定を参照しないため、保護する場合は WSL 用の Remediation を**追加で**作成します（理由と動作は[設計方針](design.md#wsl-の扱いwindows任意)を参照）。手順2と同じ流れで、以下だけ差し替えます。

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard Configuration (WSL)` |
| Detection script file | `detect-takumi-guard-wsl.ps1` をアップロード |
| Remediation script file | `install-takumi-guard-wsl.ps1` をアップロード |
| そのほかの項目 | 手順2と同じ（logged-on credentials = **Yes** / 64-bit PowerShell = **Yes** がいずれも必須） |

WSL 未導入のデバイスを含むグループへ配布しても問題ありません（WSL がなければ `COMPLIANT (no WSL distribution)` で適合になります）。

完了確認（対象デバイスの WSL 内で実行）:

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

解除する場合は [uninstall-takumi-guard-wsl.ps1](../intune/uninstall/uninstall-takumi-guard-wsl.ps1) を使用します。

---

- 「コード署名証明書が必要」と表示された場合 → [Win32アプリ配布](intune-win32.md)
- うまく動かない場合 → [トラブルシューティング](troubleshooting.md)
- 各設定値の理由・動作の仕組み → [設計方針・動作仕様](design.md)
- [ドキュメント一覧に戻る](deployment-guide.md)
