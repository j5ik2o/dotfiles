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
  # provider.tensorfold (DGX Spark x4) の窓 (limit.context) は TensorFold の窓口に合わせる (2026-10-16)。
  # 262,144 を超える範囲の品質と速さは未確認。JSON にはコメントを書けないので、ここに残す
  xdg.configFile."opencode/opencode.json" = {
    source = "${self}/config/opencode/opencode.json";
    force = true;
  };
}
