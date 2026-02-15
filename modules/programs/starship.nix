{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================
  # Starship プロンプト設定 (Catppuccin + 旧レイアウト)
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

      palette = "catppuccin_${config.catppuccin.flavor}";

      # 旧レイアウト（Powerline）
      format = lib.concatStrings [
        "[░▒▓](bg:crust fg:green)"
        "$os"
        "$username"
        "[@](fg:crust bg:green)"
        "$hostname"
        "[](fg:green bg:blue)"
        "$directory"
        "[](fg:blue bg:yellow)"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "[](fg:yellow)"
        "$fill"
        "$direnv"
        "\n"
        "$character"
      ];

      # 右プロンプト（最小限）
      right_format = lib.concatStrings [
        "$time"
        "$cmd_duration"
        "$status"
      ];

      direnv = {
        style = "bold fg:crust bg:blue";
        format = "[](fg:blue)[ $symbol$allowed ](bold fg:crust bg:blue)[░▒▓](fg:crust bg:blue)";
        disabled = false;
      };

      # ディレクトリ
      directory = {
        style = "fg:crust bg:blue";
        format = "[ $path ]($style)";
        home_symbol = " ~";
        truncate_to_repo = false;
        truncation_symbol = " ";
        truncation_length = 6;
        # 読み取り専用マーカー
        read_only = " 󰌾";
        read_only_style = "fg:red bg:blue";
      };

      # OS アイコン
      os = {
        disabled = false;
        style = "fg:crust bg:green";
        format = "[$symbol]($style)";
      };

      os.symbols = {
        Macos = "  ";
        Ubuntu = "  ";
        Debian = "  ";
      };

      # ユーザ名（常に表示）
      username = {
        show_always = true;
        style_user = "fg:crust bg:green";
        style_root = "fg:crust bg:green";
        format = "[$user]($style)";
        disabled = false;
      };

      # ホスト名（常に表示）
      hostname = {
        ssh_only = false;
        ssh_symbol = " ";
        style = "fg:crust bg:green";
        format = "[$hostname ]($style)";
      };

      # Git ブランチ
      git_branch = {
        symbol = "  ";
        style = "fg:crust bg:yellow";
        format = "[ $symbol$branch(:$remote_branch)]($style)";
      };

      # Git ステータス（シンプル）
      git_status = {
        style = "fg:crust bg:yellow";
        format = "[ $all_status ]($style)";
        conflicted = "⚡";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕";
        up_to_date = "✓";
        untracked = "?";
        stashed = "≡";
        modified = "!\${count}";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      git_metrics = {
        disabled = true;
        format = "([+$added]($added_style))[]($added_style)";
        added_style = "fg:crust bg:yellow";
        deleted_style = "fg:red bg:yellow";
      };

      # Nix シェル
      nix_shell = {
        disabled = false;
        symbol = " ";
        style = "bg:yellow fg:crust";
        format = "[](fg:yellow)[$symbol$state ]($style)[](fg:yellow)";
      };

      # Devbox シェル検出 (direnv経由の場合はDEVBOX_PROJECT_ROOTを使用)
      env_var = {
        DEVBOX_PROJECT_ROOT = {
          symbol = " ";
          style = "bg:yellow fg:crust";
          format = "[](fg:yellow)[$symbol devbox ]($style)[](fg:yellow)";
        };
      };

      fill = {
        style = "fg:surface1";
        symbol = "─";
      };

      # プロンプト文字
      character = {
        success_symbol = "[❯](bold fg:green)";
        error_symbol = "[❯](fg:red)";
        vimcmd_symbol = "[❯](bold fg:green)";
      };

      time = {
        disabled = false;
        style = "fg:sapphire";
        format = "[  $time ]($style)";
        time_format = "%T";
        utc_time_offset = "+9";
      };

      # コマンド実行時間（2秒以上のみ表示）
      cmd_duration = {
        min_time = 2000;
        style = "fg:sapphire";
        format = "[  $duration ]($style)";
      };

      # 終了ステータス（エラー時のみ）
      status = {
        disabled = false;
        format = "[ ✘ $status ]($style) ";
        style = "fg:red";
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

      palettes = {
        catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };
        catppuccin_frappe = {
          rosewater = "#f2d5cf";
          flamingo = "#eebebe";
          pink = "#f4b8e4";
          mauve = "#ca9ee6";
          red = "#e78284";
          maroon = "#ea999c";
          peach = "#ef9f76";
          yellow = "#e5c890";
          green = "#a6d189";
          teal = "#81c8be";
          sky = "#99d1db";
          sapphire = "#85c1dc";
          blue = "#8caaee";
          lavender = "#babbf1";
          text = "#c6d0f5";
          subtext1 = "#b5bfe2";
          subtext0 = "#a5adce";
          overlay2 = "#949cbb";
          overlay1 = "#838ba7";
          overlay0 = "#737994";
          surface2 = "#626880";
          surface1 = "#51576d";
          surface0 = "#414559";
          base = "#303446";
          mantle = "#292c3c";
          crust = "#232634";
        };
        catppuccin_latte = {
          rosewater = "#dc8a78";
          flamingo = "#dd7878";
          pink = "#ea76cb";
          mauve = "#8839ef";
          red = "#d20f39";
          maroon = "#e64553";
          peach = "#fe640b";
          yellow = "#df8e1d";
          green = "#40a02b";
          teal = "#179299";
          sky = "#04a5e5";
          sapphire = "#209fb5";
          blue = "#1e66f5";
          lavender = "#7287fd";
          text = "#4c4f69";
          subtext1 = "#5c5f77";
          subtext0 = "#6c6f85";
          overlay2 = "#7c7f93";
          overlay1 = "#8c8fa1";
          overlay0 = "#9ca0b0";
          surface2 = "#acb0be";
          surface1 = "#bcc0cc";
          surface0 = "#ccd0da";
          base = "#eff1f5";
          mantle = "#e6e9ef";
          crust = "#dce0e8";
        };
        catppuccin_macchiato = {
          rosewater = "#f4dbd6";
          flamingo = "#f0c6c6";
          pink = "#f5bde6";
          mauve = "#c6a0f6";
          red = "#ed8796";
          maroon = "#ee99a0";
          peach = "#f5a97f";
          yellow = "#eed49f";
          green = "#a6da95";
          teal = "#8bd5ca";
          sky = "#91d7e3";
          sapphire = "#7dc4e4";
          blue = "#8aadf4";
          lavender = "#b7bdf8";
          text = "#cad3f5";
          subtext1 = "#b8c0e0";
          subtext0 = "#a5adcb";
          overlay2 = "#939ab7";
          overlay1 = "#8087a2";
          overlay0 = "#6e738d";
          surface2 = "#5b6078";
          surface1 = "#494d64";
          surface0 = "#363a4f";
          base = "#24273a";
          mantle = "#1e2030";
          crust = "#181926";
        };
      };
    };
  };
}
