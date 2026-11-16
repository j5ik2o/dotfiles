{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.tmux = {
    enable = true;

    # 基本設定
    mouse = true;
    terminal = "xterm-256color";
    historyLimit = 50000;
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";

    # プレフィックスキー（デフォルト: Ctrl+b）
    prefix = "C-b";

    # プラグイン
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = power-theme;
        extraConfig = ''
          # Catppuccin Mocha の Mauve (#cba6f7) を使用
          set -g @tmux_power_theme "#cba6f7"
        '';
      }
    ];

    extraConfig = ''
      # デフォルトシェル（sensibleの上書きを防止）
      set -g default-shell "${pkgs.zsh}/bin/zsh"
      set -g default-command "${pkgs.zsh}/bin/zsh"

      # True color サポート
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -ag terminal-overrides ",xterm-ghostty:RGB"

      # グラフィックパススルー（Sixel/Kitty graphics protocol）
      set -g allow-passthrough on
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM

      # ペイン分割（現在のパスを維持）
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # ペイン移動（vim風）
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Alt + hjkl でペイン移動（プレフィックスなし）
      bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R

      # Alt + Shift + hjkl でペインリサイズ（プレフィックスなし）
      bind -n M-H resize-pane -L 5
      bind -n M-J resize-pane -D 5
      bind -n M-K resize-pane -U 5
      bind -n M-L resize-pane -R 5

      # Alt + n/d でペイン追加（Zellijと同じ）
      bind -n M-n split-window -h -c "#{pane_current_path}"
      bind -n M-d split-window -v -c "#{pane_current_path}"

      # Alt + w でペインを閉じる
      bind -n M-w kill-pane

      # Alt + 数字でウィンドウ切り替え
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5

      # Alt + f でペインのズーム切替
      bind -n M-f resize-pane -Z

      # 設定リロード
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # ステータスバー位置
      set -g status-position bottom

      # ウィンドウ名の自動更新を無効化（bash表示の回避）
      set -g allow-rename off
      set -g automatic-rename off
    '';
  };
}
