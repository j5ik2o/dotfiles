{
  config,
  pkgs,
  ...
}:

let
  userInfo = import ../user-info.nix;
in
{
  # ============================================================
  # Jujutsu (jj) 設定
  # Git 互換 VCS
  # ============================================================

  xdg.configFile."jj/config.toml".text = ''
    [user]
    name = "${userInfo.name}"
    email = "${userInfo.email}"

    [ui]
    editor = "nvim"
    default-command = "log"
    pager = "delta"

    [revset-aliases]
    "trunk()" = "main@origin"
  '';
}
