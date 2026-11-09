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
  # provider.dgx (DGX Spark x4、実体は vLLM) の窓 (limit.context) は 1,048,576 に合わせる。
  # モデル ID はサーバーの /v1/models が返す値と完全一致させる必要がある。
  # JSON にはコメントを書けないので、ここに残す
  xdg.configFile."opencode/opencode.json" = {
    source = "${self}/config/opencode/opencode.json";
  };
}
