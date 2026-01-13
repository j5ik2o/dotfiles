{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # ============================================================
  # Ghostty ターミナル設定
  # ============================================================
  programs.ghostty = {
    enable = true;

    # macOSではHomebrewでインストール、LinuxではNixでインストール
    package = if isDarwin then null else pkgs.ghostty;

    # シェル統合
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    settings = {
      # フォント
      font-family = "JetBrainsMono Nerd Font";
      font-family-bold = "JetBrainsMono Nerd Font";
      font-family-italic = "JetBrainsMono Nerd Font";
      font-family-bold-italic = "JetBrainsMono Nerd Font";
      font-size = 14;

      # テーマ (Catppuccin Mocha で統一)
      theme = "Catppuccin Mocha";

      # ウィンドウ
      window-padding-x = 4;
      window-padding-y = 4;
      window-decoration = true;
      macos-titlebar-style = "tabs";

      # カーソル
      cursor-style = "block";
      cursor-style-blink = true;

      # マウス
      mouse-hide-while-typing = true;

      # コピー＆ペースト
      copy-on-select = "clipboard";
      clipboard-paste-protection = true;

      # その他
      confirm-close-surface = false;
      shell-integration = "zsh";

      # キーバインド
      keybind = [
        "super+c=copy_to_clipboard"
        "super+v=paste_from_clipboard"
        "super+t=new_tab"
        "super+w=close_surface"
        "super+n=new_window"
        "super+shift+left=previous_tab"
        "super+shift+right=next_tab"
      ];
    };
  };
}
