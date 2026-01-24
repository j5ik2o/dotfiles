{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Starship プロンプト設定 (Agnoster風シンプルスタイル)
  # ============================================================
  programs.starship = {
    enable = true;
    # Zsh は sheldon で初期化するため無効化
    enableZshIntegration = false;
    enableFishIntegration = true;

    settings = {
      # 全体設定
      command_timeout = 1000;
      add_newline = false;

      # 参照デザインに合わせたPowerlineフォーマット
      format = lib.concatStrings [
        "[](bg:#030B16 fg:#7DF9AA)"
        "[ 󰀵 ](bg:#7DF9AA fg:#090c0c)"
        "[](fg:#7DF9AA bg:#1C3A5E)"
        "$time"
        "[](fg:#1C3A5E bg:#3B76F0)"
        "$directory"
        "[](fg:#3B76F0 bg:yellow)"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "[](fg:yellow bg:#030B16)"
        "$character"
      ];

      # 右プロンプト（最小限）
      right_format = lib.concatStrings [
        "$cmd_duration"
        "$status"
      ];

      # ユーザー名
      username = {
        show_always = true;
        style_user = "bg:#3B4252 fg:#D8DEE9";
        style_root = "bg:#BF616A fg:#D8DEE9";
        format = "[](fg:#3B4252)[ $user ]($style)";
      };

      # ホスト名
      hostname = {
        ssh_only = false;
        style = "bg:#3B4252 fg:#D8DEE9";
        format = "[@$hostname ]($style)[](fg:#3B4252 bg:#5E81AC)";
      };

      # ディレクトリ
      directory = {
        style = "fg:#E4E4E4 bg:#3B76F0";
        format = "[  $path ]($style)";
        truncate_to_repo = false;
        truncation_length = 0;
        # 読み取り専用マーカー
        read_only = " 󰌾";
        read_only_style = "fg:#BF616A bg:#3B76F0";
      };

      # Git ブランチ
      git_branch = {
        symbol = "  ";
        style = "fg:#1C3A5E bg:yellow";
        format = "[ $symbol$branch(:$remote_branch) ]($style)";
      };

      # Git ステータス（シンプル）
      git_status = {
        style = "fg:#1C3A5E bg:yellow";
        format = "[ $all_status ]($style)";
        conflicted = "⚡";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        up_to_date = "";
        untracked = "?";
        stashed = "📦";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      git_metrics = {
        disabled = false;
        format = "([+$added]($added_style))[]($added_style)";
        added_style = "fg:#1C3A5E bg:yellow";
        deleted_style = "fg:bright-red bg:235";
      };

      # Nix シェル
      nix_shell = {
        disabled = false;
        symbol = " ";
        style = "bg:#EBCB8B fg:#2E3440";
        format = "[](fg:#EBCB8B)[$symbol$state ]($style)[](fg:#EBCB8B)";
      };

      # Devbox シェル検出 (direnv経由の場合はDEVBOX_PROJECT_ROOTを使用)
      env_var = {
        DEVBOX_PROJECT_ROOT = {
          symbol = "📦 ";
          style = "bg:#EBCB8B fg:#2E3440";
          format = "[](fg:#EBCB8B)[$symbol devbox ]($style)[](fg:#EBCB8B)";
        };
      };

      # プロンプト文字
      character = {
        success_symbol = "[ ➜](bold green)";
        error_symbol = "[ ✗](#E84D44)";
        vimcmd_symbol = "[ ➜](bold green)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#1d2230";
        format = "[[ 󱑍 $time ](bg:#1C3A5E fg:#8DFBD2)]($style)";
      };

      # コマンド実行時間（2秒以上のみ表示）
      cmd_duration = {
        min_time = 2000;
        format = "[  $duration ]($style)";
        style = "fg:bright-white bg:18";
      };

      # 終了ステータス（エラー時のみ）
      status = {
        disabled = false;
        format = "[✘ $status]($style) ";
        style = "fg:#BF616A";
      };

      # 以下は無効化（シンプル化）
      aws.disabled = true;
      gcloud.disabled = true;
      kubernetes.disabled = true;
      docker_context.disabled = true;

      # 言語は全て無効化
      c.disabled = true;
      rust.disabled = true;
      golang.disabled = true;
      nodejs.disabled = true;
      python.disabled = true;
      java.disabled = true;
      scala.disabled = true;
      kotlin.disabled = true;
      lua.disabled = true;
      zig.disabled = true;
    };
  };
}
