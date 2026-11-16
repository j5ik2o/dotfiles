# CodeCompanion カンペ

設定ファイル: `config/nvim/lua/plugins/codecompanion.lua`

## 現在の設定

- **アダプタ**: claude_code（chat / inline / cmd すべて）
- **チャットウィンドウ**: 右側・縦分割・幅35%
- **プラグイン管理**: Nix (`vimPlugins.codecompanion-nvim`) + Lazy.nvim

## キーマップ

| キー | モード | 動作 |
|------|--------|------|
| `Space a a` | n, v | チャット開閉 |
| `Space a x` | n | チャットクリア |
| `Space a p` | n, v | アクションパレット |
| `Space a i` | n, v | インラインアシスト |

## コマンド

| コマンド | 動作 |
|----------|------|
| `:CodeCompanion` | インラインアシスト（プロンプト入力） |
| `:CodeCompanionChat` | チャットウィンドウを開く |
| `:CodeCompanionChat Toggle` | チャットウィンドウの開閉 |
| `:CodeCompanionChat Clear` | チャット履歴をクリア |
| `:CodeCompanionActions` | アクションパレットを開く |

## 基本的な使い方

### チャット

1. `Space a a` でチャットウィンドウを開く
2. プロンプトを入力して送信
3. 再度 `Space a a` で閉じる

### インラインアシスト

1. コードを選択（ビジュアルモード）
2. `Space a i` でインラインアシストを起動
3. 指示を入力するとコードが直接書き換わる

### アクションパレット

1. `Space a p` でパレットを開く
2. 定義済みアクション（説明・リファクタ等）を選択

### チャット内でのファイル参照

チャットウィンドウ内で以下のスラッシュコマンドが使える:

| コマンド | 動作 |
|----------|------|
| `/buffer` | 現在のバッファを共有 |
| `/file` | ファイルを指定して共有 |
| `/help` | Neovim ヘルプを参照 |
| `/symbols` | LSP シンボルを共有 |
| `/terminal` | ターミナル出力を共有 |

### チャット内の変数

プロンプト中で `#` 付きの変数が使える:

| 変数 | 内容 |
|------|------|
| `#buffer` | 現在のバッファ内容 |
| `#lsp` | LSP 情報 |
| `#viewport` | 表示中の範囲 |
