{
  self,
  ...
}:

{
  # ============================================================
  # CLIProxyAPI 設定
  # ============================================================
  xdg.configFile."cliproxyapi/config.yaml" = {
    source = "${self}/config/cliproxyapi/config.yaml";
    force = true;
  };
}
