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

    "docker-desktop"
    "github"

    "parallels"

    # AI / ML
    "lm-studio"
    "chatgpt"
    "claude"
    "aionui"

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

  # Homebrew クリーンアップ戦略
  homebrew.onActivation.cleanup = "zap";

  # /etc/hosts 追記
  system.activationScripts.hostsEntry.text = ''
    set -euo pipefail
    if ! /usr/bin/grep -qE '^10\.0\.1\.160[[:space:]]+j5ik2o-desktop$' /etc/hosts; then
      echo "10.0.1.160 j5ik2o-desktop" >> /etc/hosts
    fi
  '';
}
