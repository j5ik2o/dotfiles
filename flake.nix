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

    nix-clawdbot = {
      url = "github:clawdbot/nix-clawdbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      catppuccin,
      ...
    }@inputs:
    let
      # サポートするユーザー一覧
      users = [
        "j5ik2o"
        "parallels"
        "ex_j.kato"
      ];

      # デフォルトユーザー (nix-darwin用)
      defaultUser = "j5ik2o";

      # サポートするシステム
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # 各システム用の関数を生成
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # カスタムパッケージの overlay
      customOverlay = final: prev: {
        gwq = final.callPackage ./packages/gwq.nix { };
        codex = final.callPackage ./packages/codex.nix { };
        claude-code = final.callPackage ./packages/claude-code.nix { };
        copilot-chat-nvim = final.callPackage ./packages/copilot-chat.nix { };
      };

      # home-manager 設定のパス
      hmConfigPath = ./modules;

      # Neovim Lua 設定のパス
      nvimConfigPath = ./config/nvim;

      # 共通の home-manager モジュール
      commonHomeModules = [
        catppuccin.homeModules.catppuccin
        inputs.nix-clawdbot.homeManagerModules.clawdbot
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
      mkHomeConfiguration =
        {
          system,
          modules,
          username,
          homeDirectory,
          extraSpecialArgs ? { },
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              customOverlay
              inputs.nix-clawdbot.overlays.default
            ];
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "claude-code"
                "1password-cli"
              ];
          };
          modules = modules ++ [
            {
              home = {
                username = username;
                homeDirectory = homeDirectory;
                stateVersion = "24.11";
              };
            }
          ];
          extraSpecialArgs = {
            inherit
              self
              inputs
              username
              nvimConfigPath
              ;
          }
          // extraSpecialArgs;
        };

      # 全ユーザー × 全プラットフォームの homeConfigurations を生成
      mkAllHomeConfigurations = nixpkgs.lib.foldl' (
        acc: user:
        acc
        // {
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
      ) { } users;

      # nix-darwin 設定を生成する関数
      mkDarwinConfiguration =
        { system, user }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup"; # 既存ファイルを .backup に退避
                users.${user} =
                  { pkgs, ... }:
                  {
                    imports = darwinHomeModules;
                    home = {
                      username = user;
                      homeDirectory = "/Users/${user}";
                      stateVersion = "24.11";
                    };
                  };
                extraSpecialArgs = {
                  inherit self inputs nvimConfigPath;
                  username = user;
                };
              };
            }
          ];
          specialArgs = {
            inherit inputs;
            username = user;
          };
        };

      # ユーザー名を設定名用に正規化 (ドットをアンダースコアに置換)
      sanitizeUsername = name: builtins.replaceStrings [ "." ] [ "_" ] name;

      # 全ユーザー × macOSプラットフォームの darwinConfigurations を生成
      mkAllDarwinConfigurations = nixpkgs.lib.foldl' (
        acc: user:
        let
          safeName = sanitizeUsername user;
        in
        acc
        // {
          "${safeName}-darwin" = mkDarwinConfiguration {
            system = "aarch64-darwin";
            inherit user;
          };
          "${safeName}-darwin-x86" = mkDarwinConfiguration {
            system = "x86_64-darwin";
            inherit user;
          };
        }
      ) { } users;

    in
    {
      # ============================================================
      # Home Manager Configurations (standalone)
      # 全ユーザー × 全プラットフォームの組み合わせを自動生成
      # ============================================================
      homeConfigurations = mkAllHomeConfigurations;

      # ============================================================
      # nix-darwin Configurations (macOS system-level)
      # 全ユーザー × macOSプラットフォームの組み合わせを自動生成
      # ============================================================
      darwinConfigurations = mkAllDarwinConfigurations;

      # ============================================================
      # Development shells
      # ============================================================
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt
              nil
            ];
          };
        }
      );
    };
}
