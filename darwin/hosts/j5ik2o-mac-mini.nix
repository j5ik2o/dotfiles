{ ... }:

{
  # ============================================================
  # j5ik2o-mac-mini 固有設定
  # ============================================================

  # Homebrew casks (フルセット)
  homebrew.casks = [
    # ブラウザ
    "google-chrome"
    "firefox"
    "arc"

    # 開発ツール
    "jetbrains-toolbox"
    "visual-studio-code"
    "zed"

    "cursor"
    "windsurf"
    "antigravity"

    "iterm2"
    "warp"
    "wezterm"
    "ghostty"
    "cmux"

    "docker-desktop"
    "github"

    "parallels"

    # AI / ML
    "lm-studio"
    "chatgpt"
    "claude"
    "aionui"
    "codex-app"

    # ユーティリティ
    "coteditor"
    "raycast"
    "1password"
    "1password-cli"
    "karabiner-elements"
    "rectangle"
    "alt-tab"
    "stats"
    "monitorcontrol"
    "cleanshot"
    "angry-ip-scanner"
    "tailscale-app"

    # コミュニケーション
    "slack"
    "discord"
    "zoom"

    # クラウドストレージ
    "dropbox"
    "google-drive"

    # その他
    "notion"
    "obsidian"
    "mactex"
    "spotify"
  ];

  # Mac App Store アプリ
  homebrew.masApps = {
    "LINE" = 539883307;
  };

  # Homebrew クリーンアップ戦略
  homebrew.onActivation.cleanup = "zap";
}
