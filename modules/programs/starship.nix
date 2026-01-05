{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Starship プロンプト設定
  # ============================================================
  programs.starship = {
    enable = true;
    # Zsh は sheldon で初期化するため無効化
    enableZshIntegration = false;
    enableFishIntegration = true;

    settings = {
      # 全体設定
      command_timeout = 1000;  # コマンドタイムアウト (ミリ秒)

      format = lib.concatStrings [
        "[](fg:#1C3A5E)"
        "$os"
        "$username"
        "[](bg:#3B6EA5 fg:#1C3A5E)"
        "$directory"
        "[](fg:#3B6EA5 bg:#5B9BD5)"
        "$git_branch"
        "$git_status"
        "[](fg:#5B9BD5 bg:#86BBD8)"
        "$c"
        "$rust"
        "$golang"
        "$nodejs"
        "$python"
        "$java"
        "$scala"
        "$kotlin"
        "$lua"
        "$zig"
        "[](fg:#86BBD8 bg:#33658A)"
        "$docker_context"
        "$kubernetes"
        "[](fg:#33658A bg:#2F4858)"
        "$time"
        "[ ](fg:#2F4858)"
        "\n$character"
      ];

      # 右プロンプト
      right_format = lib.concatStrings [
        "$cmd_duration"
        "$status"
        "$jobs"
      ];

      # OS アイコン
      os = {
        disabled = false;
        style = "bg:#1C3A5E fg:#FFFFFF";
        symbols = {
          Macos = " ";
          Linux = " ";
          Ubuntu = " ";
          Debian = " ";
          Arch = " ";
          NixOS = " ";
          Windows = " ";
        };
      };

      # ユーザー名
      username = {
        show_always = true;
        style_user = "bg:#1C3A5E fg:#FFFFFF";
        style_root = "bg:#1C3A5E fg:#FF0000";
        format = "[$user ]($style)";
      };

      # ディレクトリ
      directory = {
        style = "bg:#3B6EA5 fg:#FFFFFF";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
          "Projects" = " ";
          "Developer" = " ";
          "Sources" = " ";
        };
      };

      # Git ブランチ
      git_branch = {
        symbol = "";
        style = "bg:#5B9BD5 fg:#1C3A5E";
        format = "[ $symbol $branch ]($style)";
      };

      # Git ステータス
      git_status = {
        style = "bg:#5B9BD5 fg:#1C3A5E";
        format = "[$all_status$ahead_behind ]($style)";
        conflicted = " ";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        up_to_date = " ";
        untracked = "?\${count}";
        stashed = " ";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };

      # 言語 - C
      c = {
        symbol = " ";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Rust
      rust = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Go
      golang = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Node.js
      nodejs = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Python
      python = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Java
      java = {
        symbol = " ";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Scala
      scala = {
        symbol = " ";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Kotlin
      kotlin = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Lua
      lua = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # 言語 - Zig
      zig = {
        symbol = "";
        style = "bg:#86BBD8 fg:#1C3A5E";
        format = "[ $symbol ($version) ]($style)";
      };

      # Docker
      docker_context = {
        symbol = "";
        style = "bg:#33658A fg:#FFFFFF";
        format = "[ $symbol $context ]($style)";
        only_with_files = true;
      };

      # Kubernetes
      kubernetes = {
        symbol = "󱃾";
        style = "bg:#33658A fg:#FFFFFF";
        format = "[ $symbol $context ]($style)";
        disabled = false;
      };

      # 時刻
      time = {
        disabled = false;
        time_format = "%H:%M";
        style = "bg:#2F4858 fg:#FFFFFF";
        format = "[  $time ]($style)";
      };

      # コマンド実行時間
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "yellow";
      };

      # 終了ステータス
      status = {
        disabled = false;
        format = "[$symbol$status]($style) ";
        symbol = "✘ ";
        success_symbol = "";
        style = "red";
      };

      # バックグラウンドジョブ
      jobs = {
        symbol = "";
        style = "blue";
        number_threshold = 1;
        format = "[$symbol$number]($style) ";
      };

      # プロンプト文字
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # Nix シェル
      nix_shell = {
        disabled = false;
        symbol = " ";
        format = "via [$symbol$state( ($name))]($style) ";
      };

      # AWS
      aws = {
        symbol = " ";
        style = "yellow";
        format = "on [$symbol$profile(($region))]($style) ";
      };

      # Terraform
      terraform = {
        symbol = "󱁢 ";
        style = "purple";
        format = "via [$symbol$version]($style) ";
      };
    };
  };
}
