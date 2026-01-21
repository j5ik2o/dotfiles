# Neovim キーマップ カンペ (AstroNvim)

AstroNvim ベースの設定。標準キーマップは公式ドキュメントと `:WhichKey` を参照。

## 参照

- AstroNvim docs: https://docs.astronvim.com/
- WhichKey: `:WhichKey`

## カスタム追加

### ターミナル

| キー | 動作 |
|------|------|
| `Esc Esc` | ターミナルモード終了 |
| `Space t 1` | ターミナル #1 |
| `Space t 2` | ターミナル #2 |
| `Space t 3` | ターミナル #3 |
| `Space t 4` | ターミナル #4 |

メモ:
- 直接コマンドなら `:2ToggleTerm` のように番号付きで開ける。

### ウィンドウサイズ調整

| キー | 動作 |
|------|------|
| `Space w h` | 幅 -2 |
| `Space w l` | 幅 +2 |
| `Space w j` | 高さ -2 |
| `Space w k` | 高さ +2 |
| `Space w =` | サイズ均等化 |

### Neo-tree Buffers

- Buffers の TERMINALS をクリックしても新規ペインは作られず、既存ターミナルへフォーカスする。
