# 2 つの入口 (homeConfigurations / darwinConfigurations) の unfree 許可述語が一致することを検証する。
# 述語は関数なので比較できない。同じ候補リストに適用した結果の集合を比較する。
{ lib, flake }:

let
  candidates = [
    "1password-cli"
    "antigravity-cli"
    "claude-code"
    "coderabbit"
    "copilot-language-server"
    "cuda_cccl"
    "cuda_cudart"
    "cuda_nvcc"
    "cuda_nvrtc"
    "libcublas"
    "obsidian"
    "sublime-text"
    "unrar"
  ];

  acceptedBy = predicate: builtins.filter (name: predicate { pname = name; }) candidates;

  standalone = flake.homeConfigurations."j5ik2o@darwin-aarch64";
  darwin = flake.darwinConfigurations."j5ik2o-darwin";

  acceptedByStandalone = acceptedBy standalone.pkgs.config.allowUnfreePredicate;
  acceptedByDarwin = acceptedBy darwin.pkgs.config.allowUnfreePredicate;

  onlyStandalone = lib.subtractLists acceptedByDarwin acceptedByStandalone;
  onlyDarwin = lib.subtractLists acceptedByStandalone acceptedByDarwin;

  finding =
    side: names: lib.optional (names != [ ]) "${side} だけが許可: ${lib.concatStringsSep ", " names}";
in
finding "homeConfigurations" onlyStandalone ++ finding "darwinConfigurations" onlyDarwin
