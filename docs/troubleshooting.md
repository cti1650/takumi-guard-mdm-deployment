# トラブルシューティング

## 動作確認コマンド

対象デバイスで実行します（macOS / Windows 共通）:

```bash
npm config get registry            # -> https://npm.flatt.tech/
pip config get global.index-url    # -> https://pypi.flatt.tech/simple/
```

ブロック動作の確認（403 エラーになれば正常）:

```bash
npm install <known-malicious-package>
pip install <known-malicious-package>
```

## ログの確認

スクリプトの出力は各 MDM のコンソールが記録します（デバイス側に専用ログファイルは残しません）。

| MDM | 確認場所 |
|------|------|
| Intune | Devices > Scripts and remediations > 該当項目 > Device status の出力 |
| Jamf Pro | Computer > History > Policy Logs |
| Iru | Iru Console > 該当スクリプトの実行結果 |

## よくある事象

### 設定済みのはずなのに「未設定」と判定される

デバイスで `npm config get registry` を実行し、実際の値を確認してください。ユーザーが手動で戻した場合、次回の評価サイクル（Intune Remediation / Jamf Recurring Check-in / Iru 監査）で自動的に再設定されます。

### npm / pip が入っているのに SKIP される

asdf / pyenv / nvm などのバージョンマネージャーで**グローバルバージョンが未設定**だと、コマンドは存在しても実行に失敗するため「対象外」としてスキップされます（例: `No version is set for python; please run 'asdf set ...'`）。保護対象にするには、デバイス側でグローバルバージョンを設定してください:

```bash
asdf set -u python <version>   # asdf の例
```

スキップの発生は、Jamf なら拡張属性の `Configured (npm only)` / `Configured (pip only)` / `Not Applicable` で、Intune / Iru ならコンソール出力の `SKIP:` 行で確認できます。

### uv / poetry / yarn / pnpm / bun は保護される？

されません。対象は npm と pip のみです。特に uv は pip の設定を参照しないため、別途対応が必要です（[設計方針](design.md#設定値固定) 参照）。

### 設定を元に戻したい（解除）

各 OS の解除スクリプトを実行してください（管理対象キーのみ削除し、ほかの設定は保持されます）:

| OS | スクリプト |
|------|------|
| Windows | [uninstall-takumi-guard.ps1](../intune/uninstall/uninstall-takumi-guard.ps1) |
| WSL | [uninstall-takumi-guard-wsl.ps1](../intune/uninstall/uninstall-takumi-guard-wsl.ps1) |
| macOS (Jamf) | [uninstall-takumi-guard.sh](../jamf-pro/policies/uninstall-takumi-guard.sh) |
| macOS (Iru) | [uninstall-takumi-guard-macos.sh](../iru/custom-scripts/uninstall-takumi-guard-macos.sh) |

個人利用であれば `npm config delete registry` と `pip config unset global.index-url` の2コマンドでも同じです。

### `npm warn Unknown user config ...` が出る

ユーザーの既存 `~/.npmrc` に npm が認識しないキーがある場合の警告で、本スクリプトとは無関係です（本スクリプトは既存キーを保持します）。動作への影響はありません。

### Intune で「コード署名証明書が必要」と言われる

[Win32アプリ配布](intune-win32.md) を参照してください（署名なしで運用できる代替手順と、回避できないケースの見分け方を記載）。

### Iru の Windows でスクリプトは成功するのに設定が反映されない

Iru のカスタムスクリプトはシステムコンテキストで実行されるとされており（実行ユーザーを指定する設定項目が公式ドキュメントに見当たりません）、その場合システムアカウント側の npm/pip 設定が変更され、ログオンユーザーには反映されません。Windows は [Intune 経由での配布](intune.md)（`Run this script using the logged-on credentials = Yes`）を推奨します。

### Iru で設定が戻されたまま再修正されない

Custom Script の **Execution Frequency** が `Install once per device` になっていないか確認してください。この設定は Pass に到達した時点で再実行されなくなります。ドリフト修正には `Run daily`（または `Run every 15 min`）を使用します。

### macOS で「No console user session」エラー

画面ロック中やログインユーザー不在のタイミングで実行された場合に発生します。ユーザーがログインしている状態で再実行されれば成功します（Jamf の Recurring Check-in / Iru の監査サイクルで自動リトライされます）。

## CI での再現確認

リポジトリの **Actions > verify-scripts > Run workflow** を手動実行すると、GitHub ホステッドランナー（Windows = PowerShell 5.1 / macOS）上で検出→投入→解除の全状態遷移を再検証できます。手元で疑わしい挙動が出た場合の切り分けに使えます。

---

- [ドキュメント一覧に戻る](deployment-guide.md)
