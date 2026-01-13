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
      # サポートするユーザー一覧
      users = [ "j5ik2o" "parallels" ];

      # デフォルトユーザー (nix-darwin用)
      defaultUser = "j5ik2o";

      # サポートするシステム
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # 各システム用の関数を生成
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # home-manager 設定のパス
      hmConfigPath = ./modules;

      # Neovim Lua 設定のパス
      nvimConfigPath = ./config/nvim;

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
      mkHomeConfiguration = { system, modules, username, homeDirectory, extraSpecialArgs ? {} }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "claude-code"
            ];
          };
          modules = modules ++ [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "24.11";
            }
          ];
          extraSpecialArgs = {
            inherit self inputs username nvimConfigPath;
          } // extraSpecialArgs;
        };

      # 全ユーザー × 全プラットフォームの homeConfigurations を生成
      mkAllHomeConfigurations = nixpkgs.lib.foldl' (acc: user:
        acc // {
          "${user}@darwin-aarch64" = mkHomeConfiguration {
            system = "aarch64-darwin";
            modules = darwinHomeModules;
            username = user;
            homeDirectory = "/Users/${user}";
          };
          "${user}@darwin-x86_64" = mkHomeConfiguration {
            system = "x86_64-darwin";
            modules = darwinHomeModules;
            username = user;
            homeDirectory = "/Users/${user}";
          };
          "${user}@linux-x86_64" = mkHomeConfiguration {
            system = "x86_64-linux";
            modules = linuxHomeModules;
            username = user;
            homeDirectory = "/home/${user}";
          };
          "${user}@linux-aarch64" = mkHomeConfiguration {
            system = "aarch64-linux";
            modules = linuxHomeModules;
            username = user;
            homeDirectory = "/home/${user}";
          };
        }
      ) {} users;

    in {
      # ============================================================
      # Home Manager Configurations (standalone)
      # 全ユーザー × 全プラットフォームの組み合わせを自動生成
      # ============================================================
      homeConfigurations = mkAllHomeConfigurations;

      # ============================================================
      # nix-darwin Configurations (macOS system-level)
      # ============================================================
      darwinConfigurations = {
        # macOS (Apple Silicon)
        "${defaultUser}-darwin" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";  # 既存ファイルを .backup に退避
                users.${defaultUser} = { pkgs, ... }: {
                  imports = darwinHomeModules;
                  home.username = defaultUser;
                  home.homeDirectory = "/Users/${defaultUser}";
                  home.stateVersion = "24.11";
                };
                extraSpecialArgs = {
                  inherit self inputs nvimConfigPath;
                  username = defaultUser;
                };
              };
            }
          ];
          specialArgs = { inherit inputs; username = defaultUser; };
        };

        # macOS (Intel) - 必要に応じて追加
        "${defaultUser}-darwin-x86" = nix-darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";  # 既存ファイルを .backup に退避
                users.${defaultUser} = { pkgs, ... }: {
                  imports = darwinHomeModules;
                  home.username = defaultUser;
                  home.homeDirectory = "/Users/${defaultUser}";
                  home.stateVersion = "24.11";
                };
                extraSpecialArgs = {
                  inherit self inputs nvimConfigPath;
                  username = defaultUser;
                };
              };
            }
          ];
          specialArgs = { inherit inputs; username = defaultUser; };
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
