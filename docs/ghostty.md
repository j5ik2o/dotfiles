# Ghostty カンペ

設定ファイル: `modules/programs/ghostty.nix`

## 現在の設定

- **フォント**: JetBrainsMono Nerd Font / サイズ14
- **カーソル**: ブロック・点滅
- **タイトルバー**: タブスタイル（macOS）
- **Option as Alt**: 有効（Claude Code の Shift+Option+Enter 対応）
- **閉じる確認**: 無効
- **テーマ**: catppuccin（`catppuccin.nix` で一元管理）
- **選択時自動コピー**: 有効

## タブ・ウィンドウ

| キー | 動作 |
|------|------|
| `Cmd+T` | 新しいタブ |
| `Cmd+W` | タブ/ペインを閉じる |
| `Cmd+N` | 新しいウィンドウ |
| `Cmd+Shift+←` | 前のタブへ |
| `Cmd+Shift+→` | 次のタブへ |

## スプリット

| キー | 動作 |
|------|------|
| `Cmd+D` | 右にスプリット |
| `Cmd+Shift+D` | 下にスプリット |
| `Cmd+Opt+矢印` | スプリット間の移動 |
| `Cmd+Ctrl+矢印` | スプリットのリサイズ |
| `Cmd+Enter` | スプリットのズーム切替 |

## コピー＆ペースト

| キー | 動作 |
|------|------|
| `Cmd+C` | コピー |
| `Cmd+V` | ペースト（保護付き） |
| テキスト選択 | 自動でクリップボードにコピー |

## フォントサイズ

| キー | 動作 |
|------|------|
| `Cmd++` | 拡大 |
| `Cmd+-` | 縮小 |
| `Cmd+0` | リセット |

## スクロール

| キー | 動作 |
|------|------|
| `Shift+PageUp/Down` | ページ単位スクロール |
| `Cmd+Home` | 一番上へ |
| `Cmd+End` | 一番下へ |

## その他

| キー | 動作 |
|------|------|
| `Cmd+,` | 設定ファイルを開く |
| `Cmd+Shift+,` | 設定をリロード |

## SSH 接続時の注意

- `TERM=xterm-ghostty` の terminfo は `~/.terminfo` に自動インストールされる
- SSH先で terminfo がない場合、シェル設定で `xterm-256color` にフォールバック
