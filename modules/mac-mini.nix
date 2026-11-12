{ pkgs, ... }:

{
  # opencode の ollama プロバイダ (config/opencode/opencode.json) は
  # http://localhost:11434/v1 を前提にしており、Ollama Cloud の :cloud モデルは
  # ローカルの ollama デーモンを経由して引く。Orca の opencode ワーカーから
  # Ollama Cloud を使うため、このホストに ollama 本体が要る。
  # DGX Spark (modules/dgx-spark.nix) と同じく常駐はさせず、使うときに
  # ollama serve を手で上げる。
  home.packages = [ pkgs.ollama ];
}
