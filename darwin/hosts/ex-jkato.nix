{ ... }:

{
  # ============================================================
  # ex-jkato (企業端末) 固有設定
  # ============================================================

  # Homebrew casks (フルセット)
  homebrew.casks = [
    # ブラウザ
    "google-chrome"

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

    "github"

    # AI / ML
    "lm-studio"
    "chatgpt"
    "claude"

    # ユーティリティ
    "coteditor"
    "raycast"
    "1password"
    "1password-cli"
    "rectangle"
    "alt-tab"
    "stats"
    "monitorcontrol"
    "cleanshot"
    "angry-ip-scanner"

    # コミュニケーション
    "slack"
  ];

  # 企業端末のため cleanup は無効
  homebrew.onActivation.cleanup = "none";
}
