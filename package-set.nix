# unfree 許可リストと overlay の唯一の定義。ここを 2 つ目の定義で置き換えない。
{
  lib,
  inputs,
}:

let
  allowedUnfreePackages = [
    "1password-cli"
    "antigravity-cli"
    "claude-code"
    "coderabbit"
    "copilot-language-server"
    # CUDA 再頒布物。ollama-cuda (modules/dgx-spark.nix) が依存する
    "cuda_cccl"
    "cuda_cudart"
    "cuda_nvcc"
    "cuda_nvrtc"
    "libcublas"
  ];

  allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfreePackages;

  # claude-code, codex は mise で管理
  overlay =
    final: prev:
    {
      gwq = final.callPackage ./packages/gwq.nix { };
      claude-code-acp = final.callPackage ./packages/claude-code-acp.nix { };
      dsh-tui = final.callPackage ./packages/dsh-tui.nix { };
      ds-bot-app = final.callPackage ./packages/ds-bot-app.nix { };
      claude-code-proxy =
        inputs.claude-code-proxy.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [ ./packages/claude-code-proxy-gpt-5-6-aliases.patch ];
          });
      claudecodex = final.callPackage ./packages/claudecodex.nix {
        claudecodexSrc = inputs.claudecodex-src;
      };
      cliproxyapi = final.callPackage ./packages/cliproxyapi.nix { };
      coderabbit = final.callPackage ./packages/coderabbit.nix { };
      herdr = final.callPackage ./packages/herdr.nix { };
      copilot-chat-nvim = final.callPackage ./packages/copilot-chat.nix { };
      # opencode 2.2.5 は nixpkgs 側の node_modules ハッシュが壊れている
      # (NixOS/nixpkgs#582673, 修正 PR #582675 は未マージ)。
      # bun 1.4.4 で実際に生成されるハッシュへ差し替える。
      # 上流で version が変われば自動的に解除される。
      opencode =
        if prev.stdenv.hostPlatform.system == "aarch64-darwin" && prev.opencode.version == "2.2.5" then
          prev.opencode.overrideAttrs (old: {
            node_modules = old.node_modules.overrideAttrs (_: {
              outputHash = "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc=";
            });
          })
        else
          prev.opencode;
    }
    // lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      # macOS で test_scan_invalid_rule_id が "Illegal byte sequence (os error 92)" で失敗するためテストをスキップ
      ast-grep = prev.ast-grep.overrideAttrs (_: {
        doCheck = false;
      });
      # macOS の Nix sandbox で test/direnv-test.zsh がハングするためテストをスキップ
      direnv = prev.direnv.overrideAttrs (_: {
        doCheck = false;
        doInstallCheck = false;
      });
      # macOS の Nix sandbox で OCI layer の特殊権限ビット保持テストが失敗するためテストをスキップ
      # あわせて libz-ng-sys のビルドに必要な cmake を補う (nixpkgs 側の nativeBuildInputs から欠落)
      mise = prev.mise.overrideAttrs (old: {
        doCheck = false;
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.cmake ];
        dontUseCmakeConfigure = true;
      });
    };

in
{
  inherit allowUnfreePredicate overlay;

  overlays = [
    inputs.nix-clawdbot.overlays.default
    overlay
  ];
}
