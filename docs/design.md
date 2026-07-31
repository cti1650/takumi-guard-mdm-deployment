# 設計方針・動作仕様

セットアップ手順の各設定値の理由と、スクリプトの動作仕様をまとめたページです。
（セットアップ作業だけなら読む必要はありません）

## 全体方針

| 方針 | 内容 |
|------|------|
| 固定値（匿名利用） | Takumi Guard の匿名利用は URL 固定でトークン不要のため、スクリプトに直接埋め込み。MDM 側での URL・環境変数・パラメータ入力を全廃 |
| コマンド方式 | 設定・検出とも `npm config` / `pip config` の標準コマンドで実施。`.npmrc` / `pip.ini` を直接編集しないため、既存のほかの設定を上書きしない |
| userロール | 対象はログオンユーザーのユーザー設定。管理者権限や system-wide の変更は行わない |
| ログはstdoutのみ | 専用ログファイルは残さない（肥大化・権限問題の回避）。出力は各 MDM のコンソールが自動記録する |

### なぜ匿名利用か

- **トークン管理リスクの回避** — 組織トークンを使うと、MDM・リポジトリ・デバイス間での秘匿情報の受け渡しとローテーション管理が発生します。匿名利用なら扱う秘匿情報がゼロになり、スクリプトをそのまま公開・レビューできます
- **主目的が「MDM への設定配布」の検証** — 本リポジトリの主眼は各 MDM での検出・投入・解除の仕組みづくりにあり、実装を最小に保つためにあえて認証なしの匿名利用を採用しています
- トレードオフとして、匿名利用ではダウンロード追跡・侵害通知（Breach Notification）は利用できません（悪性パッケージのブロック自体は有効）。組織トークン運用へ切り替える場合は、レジストリ URL の差し替えに加えて MDM 側での秘匿変数管理が必要になります

### 設定値（固定）

| 対象 | 設定コマンド | 値 |
|------|------|------|
| npm | `npm config set registry <URL>` | `https://npm.flatt.tech/` |
| PyPI (pip) | `pip config set global.index-url <URL>` | `https://pypi.flatt.tech/simple/` |

pip と pip3 はユーザー設定ファイルを共有するため、どちらか一方（存在する方）への設定で両方に反映されます。

> **対象外のパッケージマネージャー**: uv / poetry / yarn (berry) / pnpm / bun はそれぞれ独自の設定機構を持つため対象外です。特に **uv は pip の設定を参照しない**ため本スクリプトでは保護されません（対応する場合は `UV_DEFAULT_INDEX` 環境変数や `uv.toml` での別対応が必要）。

## 実行コンテキスト

- **Windows (Intune)**: ログオンユーザーのコンテキストで実行が必須。Microsoft は多くの修復で SYSTEM を推奨していますが、本スクリプトはユーザーの npm/pip 設定が対象のため、SYSTEM 実行では意味がありません。Intune では「Run this script using the logged-on credentials = Yes」がこれに当たります
- **Windows (Iru)**: Iru のカスタムスクリプトには実行ユーザーを指定する設定項目が公式ドキュメントに見当たらず（Windows 固有の設定は `Execute In` = 64/32 bit のみ）、システムコンテキストで実行されるとされています。その場合ログオンユーザーの設定には反映されないため、**Windows は Intune 経由での配布を推奨**します（Iru を使う場合は事前検証が必要）
- **macOS (Jamf/Iru)**: MDM からは root で実行されますが、スクリプト内で `stat -f "%Su" /dev/console` によりコンソールログイン中のユーザーを特定し、`sudo -u <user> bash -l` の1回の呼び出しで全処理をユーザー権限・ログインシェル環境（PATH 解決込み）で実行します。Homebrew パス（`/opt/homebrew/bin`, `/usr/local/bin`）のフォールバックも追加しています

## WSL の扱い（Windows・任意）

WSL 内の npm / pip は Linux 側のユーザー設定（`~/.npmrc` / `~/.config/pip/pip.conf`）を参照し、Windows 側の設定を一切引き継ぎません。保護する場合は WSL 専用スクリプト（[検出](../intune/detection/detect-takumi-guard-wsl.ps1) / [修復](../intune/remediation/install-takumi-guard-wsl.ps1) / [解除](../intune/uninstall/uninstall-takumi-guard-wsl.ps1)）を **2つ目の Remediation** として登録します（[手順](intune.md#5-wsl-も保護する場合任意2つ目の-remediation)）。既存スクリプトに混ぜず分離しているのは、WSL 起因の失敗や SKIP が Windows 本体の適合状態の報告を汚さないようにするためです。

| 論点 | 実装 |
|------|------|
| 実行コンテキスト | ログオンユーザー実行が必須。WSL ディストリビューションはユーザー単位に登録され（`HKCU\Lxss`）、SYSTEM からは参照できないため（[本家ドキュメント](https://shisho.dev/docs/ja/t/guard/features/admin-deployment/)にも同旨の制約が明記）。同じ理由でシステムコンテキスト実行の Iru (Windows) では配布不可 |
| 64-bit 必須 | `wsl.exe` は 64-bit の System32 にのみ存在するため「Run script in 64-bit PowerShell = Yes」が必須（既存手順の設定と同一） |
| 文字コード | `wsl.exe` の出力は既定で UTF-16LE。`WSL_UTF8=1` で UTF-8 を要求しつつ、旧バージョン向けに NUL バイト除去も併用 |
| 列挙と除外 | `wsl --list --quiet` で列挙し、コンテナツール内部用の `docker-desktop` / `rancher-desktop` / `podman-*` は除外 |
| WSL 内の実行 | `wsl -d <distro> --exec sh -lc '<POSIXスクリプト>'`。ログインシェルで PATH を解決（macOS 版の `bash -l` と同じ理屈）。埋め込みスクリプトはダブルクォート不使用の1行 POSIX sh で、PowerShell 5.1 の引数エスケープ問題を回避 |
| interop 除外 | WSL は既定で Windows の PATH を取り込むため、`/mnt/` 配下に解決される npm / pip（Windows 側の実体）は誤検出・二重設定防止のため対象外として除外 |
| スキップ規則 | 既存と同じ「未導入・実行不能 = 対象外(適合)」。`sh` を起動できないディストリビューションも SKIP（コンソール出力で確認可能）。nvm 等を `.bashrc`（対話シェルでのみ読込）だけで初期化している構成では npm が見えず SKIP になり得ます |
| CI | GitHub ホステッドの Windows ランナーは WSL2 を実行できないため verify-scripts の対象外。検証は WSL 導入済みの実機で実施 |

## 検出仕様

| スクリプト | 結果の返し方 |
|------|------|
| Intune 検出 / Iru 監査 | `Exit 0` = 設定済み（適合） / `Exit 1` = 未設定（要修復） |
| Jamf 拡張属性 | `Configured` / `Configured (npm only)` / `Configured (pip only)` / `Not Applicable`（使用可能なPMなし） / `Not Configured` / `Error`（コンソールユーザー不在時）を `<result>` タグで返却 |

- **未導入・実行不能なパッケージマネージャーは「対象外」= 適合扱い**です。存在確認は `command -v` / `Get-Command` に加えて `--version` の実行成功まで確認するため、asdf / pyenv / nvm などの「バージョン未設定の shim」（存在するが実行時に失敗する）も安全にスキップされます
- スキップは「保護されていないのに緑に見える」状態になり得るため、Jamf 拡張属性は `Configured (npm only)` 等の**部分適合値でスキップを可視化**します（Intune / Iru はコンソール出力の `SKIP:` 行で確認可能）。Smart Group の判定条件（`is Not Configured`）には影響しません
- 設定値の比較は末尾スラッシュを除去して行います

## ドリフト修正（設定が戻された場合）

| MDM | 再設定の仕組み |
|------|------|
| Intune | Remediation のスケジュール（Daily 推奨）ごとに検出 → 非適合なら修復を再実行 |
| Jamf Pro | インベントリ更新で拡張属性が `Not Configured` に戻る → Smart Group に再加入 → **Ongoing** ポリシーが再実行。`Once per computer` では再実行されないため必ず `Ongoing` を使用し、ポリシーに `Update Inventory` を含めて設定直後にスコープから離脱させます |
| Iru | Custom Script の Execution Frequency（`Run daily` / `Run every 15 min`）ごとに Audit Script を実行し、非 0 終了なら Remediation Script を実行。`Install once per device` は Pass 到達後に再実行されないため使用しません |

## 投入・解除の仕様

- 投入: `npm config set registry` / `pip config set global.index-url`。パッケージマネージャーの警告（stderr）は成功時は表示せず、失敗時のみエラー詳細として出力します
- 解除: `npm config delete registry` / `pip config unset global.index-url`。管理対象キーのみ削除し、ほかの設定は保持します。Windows は [uninstall-takumi-guard.ps1](../intune/uninstall/uninstall-takumi-guard.ps1)、WSL は [uninstall-takumi-guard-wsl.ps1](../intune/uninstall/uninstall-takumi-guard-wsl.ps1)、macOS は [Jamf 用](../jamf-pro/policies/uninstall-takumi-guard.sh) / [Iru 用](../iru/custom-scripts/uninstall-takumi-guard-macos.sh) を提供

## Windows の文字コード

Intune の実行エンジンは **Windows PowerShell 5.1** です。BOM なし UTF-8 に日本語を含めると 5.1 がレガシーコードページ (CP932) として解釈し文字化けするため、`.ps1` はコメント含め ASCII（英語）に統一し **UTF-8（BOM なし）** で保存しています（Intune 推奨エンコード。署名チェック有効時に BOM 付きが NG となる制約とも整合）。

## MDM に関する補足

- **Iru**: 2025年10月に Kandji から改称し、Apple 専用から Windows / Android 対応のクロスプラットフォーム基盤に拡張されました。Windows 対応は比較的新しいため、コンソールの細かな画面構成は公式ドキュメントも併せて確認してください
- **Jamf 拡張属性**: `<result>` タグ内の文字列がインベントリに格納されます。「未実行」と「実行したが値なし」を区別できるよう、必ず値を返す実装にしています

## 品質保証（CI）

GitHub Actions の [verify-scripts](../.github/workflows/verify-scripts.yml) ワークフローが、windows-latest（PowerShell 5.1）/ macos-latest の実機ランナー上で「PM不在 → 未設定 → 投入 → 設定済み → 解除」の状態遷移を E2E 検証します。関連スクリプト（`intune/` `jamf-pro/` `iru/` と検証ヘルパー）に変更があった push (main) / pull_request で自動実行され、Actions からの手動実行（対象 OS 選択可）にも対応します。詳細は [トラブルシューティング](troubleshooting.md) と README の CI セクションを参照。

---

- [ドキュメント一覧に戻る](deployment-guide.md)
