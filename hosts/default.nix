{ lib }:

let
  entries = builtins.readDir ./.;
  hostFiles = lib.filterAttrs (
    name: type:
    type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) entries;
  loadHost = name: import (./. + "/${name}") { inherit lib; };
in
lib.mapAttrs' (
  name: _:
  {
    name = lib.removeSuffix ".nix" name;
    value = loadHost name;
  }
) hostFiles
