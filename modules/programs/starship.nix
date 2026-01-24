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

      # Powerline寄りのフォーマット
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "\${env_var.DEVBOX_PROJECT_ROOT}"
        "\n"
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
        style = "bg:#5E81AC fg:#ECEFF4";
        format = "[ $path ]($style)[](fg:#5E81AC)";
        truncate_to_repo = false;
        truncation_length = 0;
        # 読み取り専用マーカー
        read_only = " 󰌾";
        read_only_style = "bg:#5E81AC fg:#BF616A";
      };

      # Git ブランチ
      git_branch = {
        symbol = " ";
        style = "bg:#A3BE8C fg:#2E3440";
        format = "[](fg:#A3BE8C)[$symbol$branch ]($style)[](fg:#A3BE8C)";
      };

      # Git ステータス（シンプル）
      git_status = {
        style = "bg:#A3BE8C fg:#2E3440";
        format = "[](fg:#A3BE8C)[ $all_status$ahead_behind ]($style)[](fg:#A3BE8C)";
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
        success_symbol = "[❯](bold #A3BE8C)";
        error_symbol = "[❯](bold #BF616A)";
        vimcmd_symbol = "[❮](bold #A3BE8C)";
      };

      # コマンド実行時間（2秒以上のみ表示）
      cmd_duration = {
        min_time = 2000;
        format = "[⏱ $duration]($style) ";
        style = "fg:#EBCB8B";
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
      time.disabled = true;

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
