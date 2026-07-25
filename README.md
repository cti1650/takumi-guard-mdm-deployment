# Takumi Guard MDM Deployment Scripts

[Takumi Guard](https://shisho.dev/docs/ja/t/guard/) (GMO Flatt Security) の **npm / PyPI** レジストリ設定を、MDM から各デバイスへ配布するスクリプト集です。

- 匿名利用の固定値をスクリプトに内蔵 — **MDM 側での URL・トークン・パラメータ入力は不要**（[あえて匿名利用にしている理由](docs/design.md#なぜ匿名利用か)）
- `npm config` / `pip config` の標準コマンドで設定するため、**既存の設定を上書きしません**
- 対象はログオンユーザーの設定（userロール）。未導入のパッケージマネージャーは自動スキップ

| 対象 | 設定される値 |
|------|------|
| npm | `registry=https://npm.flatt.tech/` |
| PyPI (pip) | `index-url=https://pypi.flatt.tech/simple/` |

> **個人で設定するだけなら MDM は不要です。** 以下の2コマンドで完了します:
>
> ```bash
> npm config set registry https://npm.flatt.tech/
> pip config set global.index-url https://pypi.flatt.tech/simple/
> ```
>
> 本リポジトリは、この設定を MDM 経由で組織のデバイスへ配布・維持するためのものです。

## セットアップ

各手順ページの表をコピペするだけで完結します。

| MDM | 対象OS | 手順ページ |
|-----|--------|------|
| **Intune** | Windows | [docs/intune.md](docs/intune.md) |
| **Jamf Pro** | macOS | [docs/jamf-pro.md](docs/jamf-pro.md) |
| **Iru (旧Kandji)** | macOS/Windows | [docs/iru.md](docs/iru.md) |

詳細（設計方針・トラブルシューティング・Intune Win32配布）は [docs/deployment-guide.md](docs/deployment-guide.md) から。

## ディレクトリ構成

```
.
├── intune/        # Intune 用（検出 / 修復 / アンインストール）
├── jamf-pro/      # Jamf Pro 用（拡張属性 / ポリシー）
├── iru/           # Iru 用（カスタムスクリプト / 監査）
├── docs/          # セットアップ手順・詳細ドキュメント
└── scripts/       # intunewin ビルド・CI 検証用
```

## CI

- **verify-scripts** — Windows (PowerShell 5.1) / macOS の実機ランナー上で、検出→投入→解除の全状態遷移を E2E 検証（関連スクリプト変更時の push / PR で自動実行。Actions から手動実行も可能）
- **build-intunewin** — Intune Win32 配布用の `.intunewin` パッケージをビルド（Actions から手動実行）

## License

[MIT](LICENSE)
