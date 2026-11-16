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

    claude-code-proxy = {
      url = "github:raine/claude-code-proxy/v0.1.34";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claudecodex-src = {
      url = "github:karem505/claudecodex/1bd7ee03c407bbe6d4449981b6402205487ac754";
      flake = false;
    };

    # OpenBot デスクトップアプリ (macOS / Linux)。
    # Homebrew cask が無いため、上流が提供する flake のパッケージを使う。
    # 上流の flake は nixpkgs を allowUnfreePredicate (openbot のみ) 付きで読み込むので、
    # こちらの nixpkgs 設定を変えなくても評価できる。
    openbot = {
      url = "github:nightly-labs/openbot";
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
      ];

      # 対応プラットフォームと Home Manager 構成名のサフィックス
      # nixpkgs 26.11 で x86_64-darwin のサポート終了
      platforms = {
        x86_64-linux = "linux-x86_64";
        aarch64-linux = "linux-aarch64";
        aarch64-darwin = "darwin-aarch64";
      };

      # 各システム用の関数を生成
      forAllSystems = nixpkgs.lib.genAttrs (builtins.attrNames platforms);

      # scripts/lint.sh が使うツール
      lintTools =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        with pkgs;
        [
          deadnix
          git
          nixfmt
          ruff
          shellcheck
          stylua
        ];

      packageSet = import ./package-set.nix {
        inherit (nixpkgs) lib;
        inherit inputs;
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
        (hmConfigPath + "/overrides/clawdbot.nix")
        (hmConfigPath + "/dotfiles.nix")
        (hmConfigPath + "/common.nix")
      ];

      # macOS 用 home-manager 設定
      darwinHomeModules = commonHomeModules ++ [
        (hmConfigPath + "/darwin.nix")
      ];

      # Linux 用 home-manager 設定
      linuxHomeModules = commonHomeModules ++ [
        (hmConfigPath + "/linux.nix")
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
            overlays = packageSet.overlays;
            config.allowUnfreePredicate = packageSet.allowUnfreePredicate;
          };
          modules = modules ++ [
            {
              home = {
                username = username;
                homeDirectory = homeDirectory;
                stateVersion = "24.11";
                backupFileExtension = "backup"; # 衝突した既存ファイルを .backup に退避する
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
        // nixpkgs.lib.mapAttrs' (system: suffix: {
          name = "${user}@${suffix}";
          value = mkHomeConfiguration {
            inherit system;
            modules = if isDarwinSystem system then darwinHomeModules else linuxHomeModules;
            username = user;
            homeDirectory = defaultHomeDirectory {
              inherit system;
              username = user;
            };
          };
        }) platforms
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
        // nixpkgs.lib.mapAttrs' (system: _: {
          name = "${safeName}-darwin";
          value = mkDarwinConfiguration {
            inherit system user;
          };
        }) (nixpkgs.lib.filterAttrs (system: _: isDarwinSystem system) platforms)
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

      packages = forAllSystems (
        system:
        let
          systemPkgs = import nixpkgs {
            inherit system;
            overlays = [ packageSet.overlay ];
          };
        in
        {
          dsh-tui = systemPkgs.dsh-tui;
        }
        # DS Bot のデスクトップアプリは macOS (Apple Silicon) 版しか配布されていない
        // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          ds-bot-app = systemPkgs.ds-bot-app;
        }
      );

      # --no-build の make check でも回帰を検出するため評価時にテストする
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          evalCheck =
            name: failures:
            if failures == [ ] then
              pkgs.runCommand name { } "touch $out"
            else
              throw "${name} failed: ${builtins.toJSON failures}";
          systemPkgs = import nixpkgs {
            inherit system;
            overlays = [ packageSet.overlay ];
            config.allowUnfreePredicate = packageSet.allowUnfreePredicate;
          };

          customPackages = {
            inherit (systemPkgs)
              gwq
              claude-code-acp
              dsh-tui
              claudecodex
              cliproxyapi
              coderabbit
              herdr
              ;
            copilot-chat = systemPkgs.callPackage ./packages/copilot-chat.nix { };
          }
          # DS Bot のデスクトップアプリは macOS (Apple Silicon) 版しか配布されていない
          // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
            ds-bot-app = systemPkgs.ds-bot-app;
          };
        in
        customPackages
        // {
          flake-outputs = evalCheck "flake-outputs" (
            import ./tests/flake-outputs.nix {
              inherit (nixpkgs) lib;
              flake = self;
            }
          );
          backup-policy = evalCheck "backup-policy" (
            import ./tests/backup-policy.nix {
              inherit (nixpkgs) lib;
              flake = self;
            }
          );
          unfree-parity = evalCheck "unfree-parity" (
            import ./tests/unfree-parity.nix {
              inherit (nixpkgs) lib;
              flake = self;
            }
          );
        }
      );

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
            buildInputs = [ pkgs.nil ] ++ lintTools system;
          };
        }
      );
    };
}
