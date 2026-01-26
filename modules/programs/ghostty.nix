{
  config,
  pkgs,
  lib,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # ============================================================
  # Ghostty terminfo を ~/.terminfo にインストール
  # SSH先で TERM=xterm-ghostty が認識されるようにする
  # ============================================================
  home.activation = lib.mkIf (!isDarwin) {
    installGhosttyTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      terminfo_src="${pkgs.ghostty}/share/terminfo"
      if [ -d "$terminfo_src" ]; then
        # 既存ディレクトリを安全に削除（root所有や読み取り専用でも対応）
        if [ -d "$HOME/.terminfo" ]; then
          chmod -R u+rwx "$HOME/.terminfo" 2>/dev/null || true
          rm -rf "$HOME/.terminfo" 2>/dev/null || true
        fi
        # --no-preserve=all でNix store由来の所有者・パーミッションを引き継がない
        cp -rL --no-preserve=all "$terminfo_src" "$HOME/.terminfo"
      fi
    '';
  };

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

      # テーマは catppuccin.nix で一元管理

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
      # shell-integration: SSH先で問題が起きる場合は "none" に変更
      # shell-integration = "zsh";
      # Disable shell integration title updates; we set titles in the shell.
      shell-integration-features = "no-title";

      # TERM is left as Ghostty's default; SSH fallback handled in shell init.

      # macOS: OptionキーをAltとして扱う (Claude Code/Codex の Shift+Option+Enter に必要)
      macos-option-as-alt = true;

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
