{
  self,
  ...
}:

let
  sparkConfigDir = "${self}/config/spark";
in
{
  # DGX Spark (10.0.1.60) の vLLM に Claude Code / Codex をつなぐ起動スクリプト。
  # ~/.local/bin は home.sessionPath に入っているので、どの端末からでも使える。
  home.file = {
    ".local/bin/claude-spark" = {
      source = "${sparkConfigDir}/claude-spark";
      executable = true;
      force = true;
    };

    ".local/bin/codex-spark" = {
      source = "${sparkConfigDir}/codex-spark";
      executable = true;
      force = true;
    };

    # codex-spark が Codex の namespace 型ツールを function 型へ変換するための中継。
    # 起動スクリプトがこのパスを直接探す。
    ".local/share/codex-spark/namespace_relay.py" = {
      source = "${sparkConfigDir}/namespace_relay.py";
      force = true;
    };

    # claude-spark が --mcp-config で読み込む。
    ".config/claude-spark/mcp.json" = {
      source = "${sparkConfigDir}/claude-spark-mcp.json";
      force = true;
    };
  };
}
