{ ... }:

{
  system = "aarch64-linux";
  username = "j5ik2o";
  homeDirectory = "/home/j5ik2o";

  # DGX Spark は Docker Engine と CLI がプリインストールされている。
  # Nix の docker-client を入れると PATH を奪い、プリインストールのデーモンと
  # 乖離する (client 29.8.0 / server 29.6.2)。CLI プラグインの探索パスも
  # /nix/store のみになり /usr/libexec/docker/cli-plugins を見なくなるため、
  # docker compose がシステム側 (5.2.0) と別物 (5.5.1) になる。
  # デーモンと版の揃ったシステム側 CLI に任せる。
  homeModules = [
    (
      { ... }:
      {
        dotfiles.features.dockerClient = false;
      }
    )
  ];
}
