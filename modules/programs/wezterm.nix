{ config, pkgs, lib, ... }:

{
  # ============================================================
  # WezTerm ターミナル設定
  # ============================================================
  programs.wezterm = {
    enable = true;

    extraConfig = ''
      local wezterm = require 'wezterm'

      local config = {}

      if wezterm.config_builder then
        config = wezterm.config_builder()
      end

      -- IME
      config.use_ime = true

      -- フォント (Nerd Font版 + 日本語フォールバック)
      config.font = wezterm.font_with_fallback {
        'JetBrainsMono Nerd Font',
        'Noto Sans CJK JP',
      }
      config.font_size = 14.0

      -- リガチャ有効化 (JetBrains Mono対応: != => ->)
      config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

      -- 外観
      config.window_background_opacity = 1
      -- テーマ (Catppuccin Mocha で統一)
      config.color_scheme = 'Catppuccin Mocha'

      -- タブ
      config.hide_tab_bar_if_only_one_tab = true

      -- 動作
      config.audible_bell = 'Disabled'
      config.exit_behavior = 'CloseOnCleanExit'

      -- シェル統合を無効化（プロンプトマーカーの問題回避）
      config.enable_kitty_keyboard = false
      config.enable_csi_u_key_encoding = false

      return config
    '';
  };
}
