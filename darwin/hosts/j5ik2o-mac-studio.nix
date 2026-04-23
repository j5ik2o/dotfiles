{ ... }:

{
  # ============================================================
  # j5ik2o-mac-studio 固有設定
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
    "geekbench"

    # コミュニケーション
    "slack"
    "discord"
    "gather"
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
    "Amazon Kindle" = 302584613;
    "LINE" = 539883307;
  };

  # Homebrew クリーンアップ戦略
  # cmux 手動インストール運用中のため zap を一時停止（default の "none" にフォールバック）。
  # cmux を casks に戻したら "zap" に復帰させる。
  homebrew.onActivation.cleanup = "zap";
}
