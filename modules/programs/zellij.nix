{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.zellij = {
    enable = true;
    # シェル起動時に自動でZellijを起動しない（手動で起動）
    enableZshIntegration = false;
    enableFishIntegration = false;
  };

  # Zellij 設定ファイル
  xdg.configFile."zellij/config.kdl".text = ''
    // テーマ設定 (Catppuccin Mocha)
    theme "catppuccin-mocha"

    // デフォルトレイアウト
    default_layout "compact"

    // マウスサポート
    mouse_mode true

    // コピー時にクリップボードに送る
    copy_on_select true

    // ペイン枠のスタイル
    pane_frames true

    // スクロールバッファサイズ
    scroll_buffer_size 50000

    // キーバインド（デフォルトを維持しつつカスタマイズ）
    keybinds {
      // 全モード共通（locked以外）
      shared_except "locked" {
        // Alt + n で新しいペイン（右）
        bind "Alt n" { NewPane "Right"; }
        // Alt + d で新しいペイン（下）
        bind "Alt d" { NewPane "Down"; }
        // Alt + w でペインを閉じる
        bind "Alt w" { CloseFocus; }
        // Alt + hjkl でペイン移動
        bind "Alt h" { MoveFocusOrTab "Left"; }
        bind "Alt j" { MoveFocus "Down"; }
        bind "Alt k" { MoveFocus "Up"; }
        bind "Alt l" { MoveFocusOrTab "Right"; }
        // Alt + Shift + hjkl でペインリサイズ
        bind "Alt Shift h" { Resize "Increase Left"; }
        bind "Alt Shift j" { Resize "Increase Down"; }
        bind "Alt Shift k" { Resize "Increase Up"; }
        bind "Alt Shift l" { Resize "Increase Right"; }
        // Alt + 数字でタブ切り替え
        bind "Alt 1" { GoToTab 1; }
        bind "Alt 2" { GoToTab 2; }
        bind "Alt 3" { GoToTab 3; }
        bind "Alt 4" { GoToTab 4; }
        bind "Alt 5" { GoToTab 5; }
        // Alt + f でフルスクリーン切替
        bind "Alt f" { ToggleFocusFullscreen; }
        // Alt + z でフロートペイン切替
        bind "Alt z" { ToggleFloatingPanes; }
      }
    }
  '';
}
