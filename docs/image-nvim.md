#- image.nvim 画像表示プラグイン

> NOTE: 現在の Neovim 設定は AstroNvim へ移行済みのため、`image.nvim` の設定ファイルはありません。  
> このドキュメントは過去の参考情報として残しています。

Neovim内でターミナル上に画像を表示するプラグイン。Ghostty (Kitty Graphics Protocol対応) で動作。

## キーバインド

| キー | モード | 説明 |
|------|--------|------|
| `<leader>e` | Normal | Neo-tree を開く |
| `P` | Neo-tree | 画像プレビュー表示/非表示 |
| `Enter` | Neo-tree | ファイルを開く（画像は自動表示） |

## ウィンドウ（ペイン）サイズ調整

### カスタムキーバインド（推奨）

| キー | 説明 |
|------|------|
| `<leader>wh` | 幅を減らす (-2) |
| `<leader>wl` | 幅を増やす (+2) |
| `<leader>wj` | 高さを減らす (-2) |
| `<leader>wk` | 高さを増やす (+2) |
| `<leader>Wh` | 幅を大きく減らす (-10) |
| `<leader>Wl` | 幅を大きく増やす (+10) |
| `<leader>Wj` | 高さを大きく減らす (-10) |
| `<leader>Wk` | 高さを大きく増やす (+10) |
| `<leader>w=` | 均等サイズ |

### 標準キーバインド

| キー | 説明 |
|------|------|
| `Ctrl-w =` | 全ウィンドウを均等サイズに |
| `Ctrl-w _` | 高さを最大化 |
| `Ctrl-w \|` | 幅を最大化 |

### コマンド

```vim
:resize 20          " 高さを20行に
:vertical resize 50 " 幅を50列に
```

## コマンド

| コマンド | 説明 |
|---------|------|
| `:ImageReport` | 画像レンダリングの診断レポートを表示 |

## Lua API

### プラグインの有効/無効

```lua
require("image").enable()       -- 有効化
require("image").disable()      -- 無効化
require("image").is_enabled()   -- 状態確認
require("image").create_report() -- レポート生成 (:ImageReport と同等)
```

### 画像の作成

```lua
-- ファイルから
local image = require("image").from_file("/path/to/image.png", {
  id = "my_image_id",      -- オプション: 一意のID
  window = 1000,           -- オプション: ウィンドウID
  buffer = 1000,           -- オプション: バッファID
  with_virtual_padding = true,
  inline = true,
  x = 1, y = 1,
  width = 10, height = 10,
})

-- URLから (非同期)
require("image").from_url("https://example.com/image.png", {}, function(img)
  img:render()
end)
```

### 画像の操作

```lua
image:render()           -- 画像を描画
image:render(geometry)   -- ジオメトリ指定で描画
image:clear()            -- 画像をクリア
image:move(x, y)         -- 位置を移動
image:brightness(value)  -- 明度調整
image:saturation(value)  -- 彩度調整
image:hue(value)         -- 色相調整
```

## 自動機能

設定済みの機能:

- **画像ファイルを直接開く**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.avif` を開くと自動表示
- **Markdown内の画像**: `![alt](path/to/image.png)` が自動表示
- **リモート画像**: Markdown内のURL画像も自動ダウンロード・表示

## 設定ファイル

`config/nvim-astro/lua/plugins/image.lua`:

```lua
opts = {
  backend = "kitty",              -- Ghostty対応
  processor = "magick_rock",      -- ImageMagick FFI使用
  integrations = {
    markdown = {
      enabled = true,
      clear_in_insert_mode = false,  -- 挿入モードでも表示維持
      download_remote_images = true, -- URLからダウンロード
      only_render_image_at_cursor = false,
    },
  },
  max_height_window_percentage = 50,  -- 画像の最大高さ (%)
  window_overlap_clear_enabled = true,
  hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
}
```

## トラブルシューティング

### 画像が表示されない

1. **Ghostty内で実行しているか確認**
   ```bash
   echo $TERM  # xterm-ghostty であること
   ```

2. **tmux経由の場合**
   `~/.tmux.conf` に以下を追加:
   ```
   set -gq allow-passthrough on
   set -g visual-activity off
   ```

3. **ImageMagickの確認**
   ```bash
   magick --version
   ```

4. **診断レポート**
   Neovim内で `:ImageReport` を実行

### magickモジュールエラー

Nixで `extraLuaPackages = ps: [ ps.magick ];` が設定されていることを確認。

## 参考

- [3rd/image.nvim](https://github.com/3rd/image.nvim)
- [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
