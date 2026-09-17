{ ... }:

{
  system = "aarch64-linux";
  username = "j5ik2o";
  homeDirectory = "/home/j5ik2o";

  homeModules = [
    (
      { config, lib, ... }:
      let
        hfHome = "${config.home.homeDirectory}/.local/share/huggingface";
      in
      {
        # DGX Spark は Docker Engine と CLI がプリインストールされている。
        # Nix の docker-client を入れると PATH を奪い、プリインストールのデーモンと
        # 乖離する (client 29.8.0 / server 29.6.2)。CLI プラグインの探索パスも
        # /nix/store のみになり /usr/libexec/docker/cli-plugins を見なくなるため、
        # docker compose がシステム側 (5.2.0) と別物 (5.5.1) になる。
        # デーモンと版の揃ったシステム側 CLI に任せる。
        dotfiles.features.dockerClient = false;

        # Hugging Face のモデルキャッシュ。既定の ~/.cache/huggingface はキャッシュ掃除で
        # 消える場所なので、数十〜数百 GB の重みは ~/.local/share へ置く。
        # vLLM 等のコンテナにはこのディレクトリをマウントして再ダウンロードを避ける。
        home.sessionVariables.HF_HOME = hfHome;

        # 存在しないまま docker -v でマウントすると root 所有で作られ、
        # ホスト側から書き換えられなくなるため先に作る。
        home.activation.createHfHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "${hfHome}"
        '';
      }
    )
  ];
}
