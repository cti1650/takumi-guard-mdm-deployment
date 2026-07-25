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

## 実行コンテキスト

- **Windows (Intune/Iru)**: ログオンユーザーのコンテキストで実行が必須。Microsoft は多くの修復で SYSTEM を推奨していますが、本スクリプトはユーザーの npm/pip 設定が対象のため、SYSTEM 実行では意味がありません。Intune では「Run this script using the logged-on credentials = Yes」がこれに当たります
- **macOS (Jamf/Iru)**: MDM からは root で実行されますが、スクリプト内で `stat -f "%Su" /dev/console` によりコンソールログイン中のユーザーを特定し、`sudo -u <user> bash -l` の1回の呼び出しで全処理をユーザー権限・ログインシェル環境（PATH 解決込み）で実行します。Homebrew パス（`/opt/homebrew/bin`, `/usr/local/bin`）のフォールバックも追加しています

## 検出仕様

| スクリプト | 結果の返し方 |
|------|------|
| Intune 検出 / Iru 監査 | `Exit 0` = 設定済み（適合） / `Exit 1` = 未設定（要修復） |
| Jamf 拡張属性 | `<result>Configured</result>` / `<result>Not Configured</result>` / `<result>Error</result>`（コンソールユーザー不在時） |

- **未導入・実行不能なパッケージマネージャーは「対象外」= 適合扱い**です。存在確認は `command -v` / `Get-Command` に加えて `--version` の実行成功まで確認するため、asdf / pyenv / nvm などの「バージョン未設定の shim」（存在するが実行時に失敗する）も安全にスキップされます
- 設定値の比較は末尾スラッシュを除去して行います

## 投入・解除の仕様

- 投入: `npm config set registry` / `pip config set global.index-url`。パッケージマネージャーの警告（stderr）は成功時は表示せず、失敗時のみエラー詳細として出力します
- 解除（Windows のみスクリプト提供）: `npm config delete registry` / `pip config unset global.index-url`。管理対象キーのみ削除し、ほかの設定は保持します。macOS はアンインストールスクリプト未提供です（必要になった際に同じ方式で追加可能）

## Windows の文字コード

Intune の実行エンジンは **Windows PowerShell 5.1** です。BOM なし UTF-8 に日本語を含めると 5.1 がレガシーコードページ (CP932) として解釈し文字化けするため、`.ps1` はコメント含め ASCII（英語）に統一し **UTF-8（BOM なし）** で保存しています（Intune 推奨エンコード。署名チェック有効時に BOM 付きが NG となる制約とも整合）。

## MDM に関する補足

- **Iru**: 2025年10月に Kandji から改称し、Apple 専用から Windows / Android 対応のクロスプラットフォーム基盤に拡張されました。Windows 対応は比較的新しいため、コンソールの細かな画面構成は公式ドキュメントも併せて確認してください
- **Jamf 拡張属性**: `<result>` タグ内の文字列がインベントリに格納されます。「未実行」と「実行したが値なし」を区別できるよう、必ず値を返す実装にしています

## 品質保証（CI）

GitHub Actions の [verify-scripts](../.github/workflows/verify-scripts.yml) ワークフロー（手動実行）が、windows-latest（PowerShell 5.1）/ macos-latest の実機ランナー上で「PM不在 → 未設定 → 投入 → 設定済み → 解除」の状態遷移を E2E 検証します。詳細は [トラブルシューティング](troubleshooting.md) と README の CI セクションを参照。

---

- [ドキュメント一覧に戻る](deployment-guide.md)
