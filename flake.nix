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
      # claude-code, codex は mise で管理
      customOverlay = final: prev: {
        gwq = final.callPackage ./packages/gwq.nix { };
        claude-code-acp = final.callPackage ./packages/claude-code-acp.nix { };
        cliproxyapi = final.callPackage ./packages/cliproxyapi.nix { };
      };

      # home-manager 設定のパス
      hmConfigPath = ./modules;

      # Neovim Lua 設定のパス
      nvimConfigPath = ./config/nvim;

      # ホスト定義
      hosts = import ./hosts { inherit (nixpkgs) lib; };

      isDarwinSystem = system: nixpkgs.lib.hasSuffix "darwin" system;

      # 共通の home-manager モジュール
      commonHomeModules = [
        catppuccin.homeModules.catppuccin
        "${hmConfigPath}/overrides/clawdbot.nix"
        "${hmConfigPath}/dotfiles.nix"
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
        {
          system,
          user,
          homeDirectory ? "/Users/${user}",
          homeModules ? [ ],
          darwinModules ? [ ],
          extraSpecialArgs ? { },
          expectedHostName ? null, # ホスト名の期待値（チェック用）
        }:
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
                    imports = darwinHomeModules ++ homeModules;
                    home = {
                      username = user;
                      homeDirectory = homeDirectory;
                      stateVersion = "24.11";
                    };
                  };
                extraSpecialArgs = {
                  inherit self inputs nvimConfigPath;
                  username = user;
                }
                // extraSpecialArgs;
              };
            }
          ]
          ++ darwinModules;
          specialArgs = {
            inherit inputs;
            username = user;
            inherit expectedHostName; # darwin/default.nix でチェック用に渡す
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

      defaultHomeDirectory =
        host: if isDarwinSystem host.system then "/Users/${host.username}" else "/home/${host.username}";

      hostNameModule =
        hostName:
        { ... }:
        {
          dotfiles.hostName = hostName;
        };

      featureModulesForHost =
        host:
        let
          features = host.features or { };
          enableClawdbot = features.clawdbot or false;
        in
        nixpkgs.lib.optionals enableClawdbot [
          (
            { ... }:
            {
              dotfiles.features.clawdbot = true;
            }
          )
        ];

      mkHostHomeConfiguration =
        hostName: host:
        let
          baseModules = if isDarwinSystem host.system then darwinHomeModules else linuxHomeModules;
          homeModules = host.homeModules or [ ];
          featureModules = featureModulesForHost host;
          homeDirectory = host.homeDirectory or (defaultHomeDirectory host);
        in
        mkHomeConfiguration {
          system = host.system;
          modules = baseModules ++ featureModules ++ homeModules ++ [ (hostNameModule hostName) ];
          username = host.username;
          homeDirectory = homeDirectory;
          extraSpecialArgs = host.extraSpecialArgs or { };
        };

      mkHostDarwinConfiguration =
        hostName: host:
        let
          homeModules = host.homeModules or [ ];
          featureModules = featureModulesForHost host;
          homeDirectory = host.homeDirectory or (defaultHomeDirectory host);
          hostDarwinModule = ./darwin/hosts + "/${hostName}.nix";
          hostDarwinModules = if builtins.pathExists hostDarwinModule then [ hostDarwinModule ] else [ ];
        in
        mkDarwinConfiguration {
          system = host.system;
          user = host.username;
          homeDirectory = homeDirectory;
          homeModules = featureModules ++ homeModules ++ [ (hostNameModule hostName) ];
          darwinModules = hostDarwinModules;
          extraSpecialArgs = host.extraSpecialArgs or { };
          expectedHostName = hostName; # ホスト名チェック用
        };

      hostHomeConfigurations = nixpkgs.lib.mapAttrs mkHostHomeConfiguration hosts;

      hostDarwinConfigurations = nixpkgs.lib.mapAttrs mkHostDarwinConfiguration (
        nixpkgs.lib.filterAttrs (_: host: isDarwinSystem host.system) hosts
      );

    in
    {
      # ============================================================
      # Home Manager Configurations (standalone)
      # 全ユーザー × 全プラットフォームの組み合わせを自動生成
      # ============================================================
      homeConfigurations = mkAllHomeConfigurations // hostHomeConfigurations;

      # ============================================================
      # nix-darwin Configurations (macOS system-level)
      # 全ユーザー × macOSプラットフォームの組み合わせを自動生成
      # ============================================================
      darwinConfigurations = mkAllDarwinConfigurations // hostDarwinConfigurations;

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
