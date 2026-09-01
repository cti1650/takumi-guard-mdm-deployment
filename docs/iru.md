# Iru セットアップ手順 (macOS / Windows)

Custom Script ライブラリアイテム 1 つに、検出（Audit Script）と設定投入（Remediation Script）をまとめて登録します。**貼り付ける値はすべて下表のとおり**です。URL・トークン・環境変数の入力は不要です。

> Iru は 2025年10月に Kandji から改称された比較的新しいプラットフォームです。画面構成が本手順と異なる場合は公式ドキュメントを併せて確認してください。
>
> **Blueprints は Assignment Maps になりました。** 2026年4月1日に旧 Classic Blueprints はすべて Assignment Maps へ自動移行済みです。ライブラリアイテムの割り当ては、Blueprint を開いて **Edit assignments** から Library Item Bank の項目を Assignment Map にドラッグして行います。Windows と macOS を1つの Blueprint で運用している場合は、条件ブロックで OS 別にスコープを分けられます。

## 1. Custom Script を登録 (macOS)

Iru Console > **Library** > Custom Script を追加

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard` |
| Blueprints | 対象 Blueprint（Assignment Map）を選択 |
| Execution Frequency | `Run daily` ← 重要 |
| Audit Script | [detect-takumi-guard.sh](../iru/custom-scripts/detect-takumi-guard.sh) の内容を貼り付け |
| Remediation Script | [install-takumi-guard-macos.sh](../iru/custom-scripts/install-takumi-guard-macos.sh) の内容を貼り付け |
| Restart after a successful execution | チェックしない |
| Self Service | 未設定のままで可 |

> **Execution Frequency は `Run daily` を選びます**（厳格に運用する場合は `Run every 15 min`）。選択肢は `Install once per device` / `Run every 15 min` / `Run daily` / `Run on-demand from Self Service` の4つですが、`Install once per device` は Pass に到達した時点で再実行されなくなるため、ユーザーが設定を戻してもドリフトが修正されません。
>
> 動作は Audit → Remediation の2段です。Audit Script が終了コード 0 なら **Pass**、非 0 なら Remediation Script が実行され、それが 0 で終われば **Remediated**、非 0 なら **Error** としてアラートが上がります。本スクリプトは未設定を「非 0」で返して投入につなげる設計なので、初回に Remediated と表示されるのは正常です。
>
> macOS のカスタムスクリプトは常に root で実行されます（実行ユーザーを選ぶ設定項目はありません）。npm / pip の設定はユーザーごとなので、スクリプト側でコンソールにログイン中のユーザーのセッションへ入り直して読み書きします。詳細は [設計方針](design.md#実行コンテキスト) を参照してください。

## 2. Custom Script を登録 (Windows) ※事前検証を推奨

| 設定項目 | 値 |
|------|------|
| Name | `Takumi Guard (Windows)` |
| Blueprints | 対象 Blueprint（Assignment Map）を選択 |
| Audit Script | [detect-takumi-guard.ps1](../intune/detection/detect-takumi-guard.ps1) の内容を貼り付け |
| Remediation Script | [install-takumi-guard-windows.ps1](../iru/custom-scripts/install-takumi-guard-windows.ps1) の内容を貼り付け |
| Command Line Parameters | 空欄 |
| Execute In | `64 bit` |

> ⚠️ **Windows は Iru では非推奨です。** Iru の Windows カスタムスクリプトは**システムコンテキストで実行**され、実行ユーザーを指定する設定項目は提供されていません（[公式の説明](https://www.iru.com/blog/windows-powershell-scripts)にも "Scripts execute with system-level context and run independently of user interaction" と明記）。本スクリプトはシステムアカウント側の npm/pip 設定を変更するため、**ログオンユーザーには反映されません**。
>
> Windows は [Intune 経由での配布](intune.md)（"Run this script using the logged-on credentials = Yes" が指定可能）を推奨します。Iru で配布する場合は、テストデバイスで手順3の完了確認を必ず実施してください。

## 3. 完了確認（対象デバイスで実行）

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

## 4. 解除（アンインストール）する場合

対象から外すデバイスの設定を元に戻すには、解除スクリプトを Custom Script（Remediation Script）として登録し、解除対象の Blueprint に割り当てます。

| OS | スクリプト |
|------|------|
| macOS | [uninstall-takumi-guard-macos.sh](../iru/custom-scripts/uninstall-takumi-guard-macos.sh) |
| Windows | [uninstall-takumi-guard.ps1](../intune/uninstall/uninstall-takumi-guard.ps1)（上記の事前検証に関する注意が同様に該当） |

---

- うまく動かない場合 → [トラブルシューティング](troubleshooting.md)
- 各設定値の理由・動作の仕組み → [設計方針・動作仕様](design.md)
- [ドキュメント一覧に戻る](deployment-guide.md)
