{ config, pkgs, lib, username, ... }:

let
  # WSL 検出
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
in
{
  # ============================================================
  # Git 設定
  # ============================================================
  programs.git = {
    enable = true;

    # Git 設定 (新しい settings 形式)
    settings = {
      # ユーザー情報
      user = {
        name = "j5ik2o";
        email = "j5ik2o@gmail.com";  # 必要に応じて変更
      };

      # デフォルトブランチ
      init.defaultBranch = "main";

      # プッシュ設定
      push = {
        default = "current";
        autoSetupRemote = true;
      };

      # プル設定
      pull = {
        rebase = true;
      };

      # フェッチ設定
      fetch = {
        prune = true;
        pruneTags = true;
      };

      # マージ設定
      merge = {
        conflictstyle = "diff3";
        ff = "only";
      };

      # リベース設定
      rebase = {
        autoSquash = true;
        autoStash = true;
      };

      # diff 設定
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };

      # コア設定
      core = {
        editor = "nvim";
        autocrlf = "input";
        ignorecase = false;
        quotepath = false;
      };

      # 認証設定
      credential = {
        helper =
          if pkgs.stdenv.isDarwin then "osxkeychain"
          else if isWSL then "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe"
          else "cache --timeout=3600";
      };

      # URL 置換
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };

      # GitHub CLI 統合
      gh = {
        protocol = "ssh";
      };

      # パフォーマンス
      feature = {
        manyFiles = true;
      };

      # 署名 (GPG/SSH)
      # commit.gpgsign = true;
      # gpg.format = "ssh";
      # user.signingkey = "~/.ssh/id_ed25519.pub";

      # エイリアス
      alias = {
        # 基本操作
        s = "status -sb";
        a = "add";
        aa = "add --all";
        c = "commit";
        cm = "commit -m";
        ca = "commit --amend";
        can = "commit --amend --no-edit";

        # ブランチ操作
        b = "branch";
        ba = "branch -a";
        bd = "branch -d";
        bD = "branch -D";
        co = "checkout";
        cob = "checkout -b";
        sw = "switch";
        swc = "switch -c";

        # 履歴表示
        l = "log --oneline -20";
        ll = "log --oneline --graph --all -30";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        lga = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all";

        # 差分表示
        d = "diff";
        ds = "diff --staged";
        dc = "diff --cached";

        # リモート操作
        f = "fetch --all --prune";
        p = "push";
        pf = "push --force-with-lease";
        pu = "push -u origin HEAD";
        pl = "pull --rebase";

        # スタッシュ
        st = "stash";
        stp = "stash pop";
        stl = "stash list";
        std = "stash drop";

        # リセット
        unstage = "reset HEAD --";
        undo = "reset --soft HEAD^";
        hard = "reset --hard";

        # クリーンアップ
        clean-branches = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d";

        # ユーティリティ
        who = "shortlog -sne";
        root = "rev-parse --show-toplevel";
        aliases = "config --get-regexp ^alias\\.";
        last = "log -1 HEAD --format=format:'%Cred%H'";
        contributors = "shortlog --summary --numbered";
      };
    };

    # グローバル gitignore
    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "Icon"
      "._*"
      ".DocumentRevisions-V100"
      ".fseventsd"
      ".Spotlight-V100"
      ".TemporaryItems"
      ".Trashes"
      ".VolumeIcon.icns"
      ".com.apple.timemachine.donotpresent"

      # エディタ
      "*~"
      "*.swp"
      "*.swo"
      ".idea/"
      ".vscode/"
      "*.sublime-project"
      "*.sublime-workspace"

      # 環境
      ".env"
      ".env.local"
      ".env.*.local"
      ".envrc"

      # ログ
      "*.log"
      "npm-debug.log*"
      "yarn-debug.log*"
      "yarn-error.log*"

      # 依存関係
      "node_modules/"
      "vendor/"
      ".bundle/"

      # ビルド
      "dist/"
      "build/"
      "target/"
      "*.egg-info/"
      "__pycache__/"
      "*.pyc"

      # その他
      ".direnv/"
      ".cache/"
      "*.bak"
      "*.tmp"
    ];

    # LFS サポート
    lfs.enable = true;
  };

  # ============================================================
  # Delta (diff 表示改善) - 別のプログラムとして設定
  # ============================================================
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "Dracula";
      plus-style = "syntax #003800";
      minus-style = "syntax #3f0001";
      decorations = {
        commit-decoration-style = "bold yellow box ul";
        file-style = "bold yellow ul";
        file-decoration-style = "none";
      };
    };
  };

  # ============================================================
  # GitHub CLI 設定
  # ============================================================
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      editor = "nvim";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
        pc = "pr create";
        pl = "pr list";
        is = "issue list";
        ic = "issue create";
        iv = "issue view";
      };
    };
  };

  # ============================================================
  # ghq 設定
  # ============================================================
  # ghq はパッケージのみ (common.nix)。設定は ~/.config/git/config で管理
  # [ghq]
  #   root = ~/ghq

  # ============================================================
  # lazygit 設定
  # ============================================================
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          selectedLineBgColor = [ "default" ];
        };
        showIcons = true;
      };
      git = {
        pagers = [
          {
            pager = "delta --dark --paging=never";
            colorArg = "always";
          }
        ];
      };
    };
  };
}
