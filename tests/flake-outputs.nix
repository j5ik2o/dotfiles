{ lib, flake }:

lib.runTests {
  testDevelopmentShellPlatforms = {
    expr = lib.mapAttrs (_: shells: shells.default.system) flake.devShells;
    expected = {
      aarch64-darwin = "aarch64-darwin";
      aarch64-linux = "aarch64-linux";
      x86_64-linux = "x86_64-linux";
    };
  };

  testHomeConfigurationPlatforms = {
    expr = lib.mapAttrs (_: home: home.pkgs.stdenv.hostPlatform.system) flake.homeConfigurations;
    expected = {
      ex-jkato = "aarch64-darwin";
      "ex_j.kato@darwin-aarch64" = "aarch64-darwin";
      "ex_j.kato@linux-aarch64" = "aarch64-linux";
      "ex_j.kato@linux-x86_64" = "x86_64-linux";
      instance-dinov2-gpu2-c = "x86_64-linux";
      j5ik2o-desktop = "x86_64-linux";
      j5ik2o-mac-mini = "aarch64-darwin";
      j5ik2o-mac-studio = "aarch64-darwin";
      j5ik2o-macbook-air = "aarch64-darwin";
      "j5ik2o@darwin-aarch64" = "aarch64-darwin";
      "j5ik2o@linux-aarch64" = "aarch64-linux";
      "j5ik2o@linux-x86_64" = "x86_64-linux";
      minecraft-server = "x86_64-linux";
      openclaw = "x86_64-linux";
      parallels-ubuntu = "aarch64-linux";
      "parallels@darwin-aarch64" = "aarch64-darwin";
      "parallels@linux-aarch64" = "aarch64-linux";
      "parallels@linux-x86_64" = "x86_64-linux";
    };
  };

  testDarwinConfigurationPlatforms = {
    expr = lib.mapAttrs (_: darwin: darwin.pkgs.stdenv.hostPlatform.system) flake.darwinConfigurations;
    expected = {
      ex-jkato = "aarch64-darwin";
      ex_j_kato-darwin = "aarch64-darwin";
      j5ik2o-darwin = "aarch64-darwin";
      j5ik2o-mac-mini = "aarch64-darwin";
      j5ik2o-mac-studio = "aarch64-darwin";
      j5ik2o-macbook-air = "aarch64-darwin";
      parallels-darwin = "aarch64-darwin";
    };
  };

  testHomeUserDirectories = {
    expr =
      map
        (
          name:
          let
            home = flake.homeConfigurations.${name}.config.home;
          in
          [
            home.username
            home.homeDirectory
          ]
        )
        [
          "ex_j.kato@darwin-aarch64"
          "j5ik2o@linux-x86_64"
          "parallels@linux-aarch64"
        ];
    expected = [
      [
        "ex_j.kato"
        "/Users/ex_j.kato"
      ]
      [
        "j5ik2o"
        "/home/j5ik2o"
      ]
      [
        "parallels"
        "/home/parallels"
      ]
    ];
  };
}
