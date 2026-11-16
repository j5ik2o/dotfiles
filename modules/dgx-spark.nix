# DGX Spark (GB10 / DGX OS) 共通の Home Manager 設定。hosts/spark-*.nix から読む
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hfHome = "${config.home.homeDirectory}/.local/share/huggingface";

  # 非 NixOS では libcuda.so.1 / libnvidia-ml.so.1 は NVIDIA ドライバ側
  # (/usr/lib/aarch64-linux-gnu) にあり、Nix ビルドのバイナリからは見えない。
  # Ubuntu の lib ディレクトリを丸ごと LD_LIBRARY_PATH に載せると Nix 側の
  # libstdc++ 等まで上書きされてしまうため、必要な 2 本だけを集めて渡す。
  nvidiaDriverLibs = pkgs.runCommand "nvidia-driver-libs" { } ''
    mkdir -p "$out/lib"
    for so in libcuda.so.1 libnvidia-ml.so.1; do
      ln -s "/usr/lib/aarch64-linux-gnu/$so" "$out/lib/$so"
    done
  '';

  # GB10 は sm_121。nixpkgs の cudaPackages 12.9 は既定 capability に 12.1 を
  # 含むため native にビルドできるが、既定の 9 アーキ分を全部ビルドするのは
  # 時間の無駄なので実機の 1 アーキに絞る。
  # ドライバのライブラリは systemd service ではなく実行ファイル側に持たせる
  # (手で ollama serve を上げても効くようにするため)。
  ollamaCuda = pkgs.symlinkJoin {
    name = "ollama-cuda-wrapped";
    paths = [
      (pkgs.ollama.override {
        acceleration = "cuda";
        cudaArches = [ "sm_121" ];
      })
    ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/ollama" \
        --suffix LD_LIBRARY_PATH : "${nvidiaDriverLibs}/lib"
    '';
  };
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

  # Ollama は動作検証用。常駐させず、使うときに ollama serve を手で上げる。
  home.packages = [ ollamaCuda ];
}
