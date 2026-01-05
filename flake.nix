{
  description = "j5ik2o's dotfiles - Home Manager & nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }@inputs:
    let
      # ユーザー設定
      username = "j5ik2o";

      # サポートするシステム
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # 各システム用の関数を生成
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # home-manager 設定のパス
      hmConfigPath = ./modules;

      # 共通の home-manager モジュール
      commonHomeModules = [
        "${hmConfigPath}/common.nix"
      ];

      # macOS 用 home-manager 設定
      darwinHomeModules = commonHomeModules ++ [
        "${hmConfigPath}/darwin.nix"
      ];

      # Linux 用 home-manager 設定
      linuxHomeModules = commonHomeModules ++ [
        "${hmConfigPath}/linux.nix"
      ];

      # home-manager 設定を生成する関数
      mkHomeConfiguration = { system, modules, homeDirectory, extraSpecialArgs ? {} }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = modules ++ [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "24.11";
            }
          ];
          extraSpecialArgs = {
            inherit inputs username;
          } // extraSpecialArgs;
        };

    in {
      # ============================================================
      # Home Manager Configurations (standalone)
      # ============================================================
      homeConfigurations = {
        # macOS (Apple Silicon)
        "${username}@darwin-aarch64" = mkHomeConfiguration {
          system = "aarch64-darwin";
          modules = darwinHomeModules;
          homeDirectory = "/Users/${username}";
        };

        # macOS (Intel)
        "${username}@darwin-x86_64" = mkHomeConfiguration {
          system = "x86_64-darwin";
          modules = darwinHomeModules;
          homeDirectory = "/Users/${username}";
        };

        # Linux (x86_64)
        "${username}@linux-x86_64" = mkHomeConfiguration {
          system = "x86_64-linux";
          modules = linuxHomeModules;
          homeDirectory = "/home/${username}";
        };

        # Linux (aarch64)
        "${username}@linux-aarch64" = mkHomeConfiguration {
          system = "aarch64-linux";
          modules = linuxHomeModules;
          homeDirectory = "/home/${username}";
        };
      };

      # ============================================================
      # nix-darwin Configurations (macOS system-level)
      # ============================================================
      darwinConfigurations = {
        # macOS (Apple Silicon)
        "${username}-darwin" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";  # 既存ファイルを .backup に退避
                users.${username} = { pkgs, ... }: {
                  imports = darwinHomeModules;
                  home.username = username;
                  home.homeDirectory = "/Users/${username}";
                  home.stateVersion = "24.11";
                };
                extraSpecialArgs = {
                  inherit inputs username;
                };
              };
            }
          ];
          specialArgs = { inherit inputs username; };
        };

        # macOS (Intel) - 必要に応じて追加
        "${username}-darwin-x86" = nix-darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";  # 既存ファイルを .backup に退避
                users.${username} = { pkgs, ... }: {
                  imports = darwinHomeModules;
                  home.username = username;
                  home.homeDirectory = "/Users/${username}";
                  home.stateVersion = "24.11";
                };
                extraSpecialArgs = {
                  inherit inputs username;
                };
              };
            }
          ];
          specialArgs = { inherit inputs username; };
        };
      };

      # ============================================================
      # Development shells
      # ============================================================
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-classic
              nil
            ];
          };
        }
      );
    };
}
