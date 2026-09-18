{ ... }:

{
  system = "aarch64-linux";
  username = "j5ik2o";
  homeDirectory = "/home/j5ik2o";

  homeModules = [ ../modules/dgx-spark.nix ];
}
