{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================
  # システムパッケージ
  # ============================================================
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # ============================================================
  # フォント設定
  # ============================================================
  fonts = {
    packages = with pkgs; [
      # Nerd Fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.meslo-lg
      nerd-fonts.monaspace

      # 日本語フォント
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      source-han-sans
      source-han-serif
    ];
  };
}
