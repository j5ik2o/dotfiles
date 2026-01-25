{
  config,
  pkgs,
  lib,
  self,
  ...
}:

{
  # ============================================================
  # OpenCode 設定
  # ============================================================
  xdg.configFile."opencode/opencode.json" = {
    source = "${self}/config/opencode/opencode.json";
    force = true;
  };
}
