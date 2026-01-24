{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeBinaryWrapper,
  nix-update-script,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
let
  platformMap = {
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "aarch64-darwin" = "aarch64-apple-darwin";
  };

  platform = platformMap.${stdenv.hostPlatform.system}
    or (throw "unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-darwin" = "sha256-hoRaw3UWpS0npu2gWlWpL6+EZ5qP9uSalChDw0PC2eM=";
    "x86_64-darwin" = "sha256-Nsu4F1CW2OaR9mFu0Kq8YWsnvSBNWK/iAIDN1v/834g=";
    "aarch64-linux" = "sha256-C/CPgP04Jc11jg8jo15Ex5B1R2xIgOVhPypgWntatTw=";
    "x86_64-linux" = "sha256-t2PiNVc7Tcvy8jnzrk+XEGRNRq0qKSYnRyWEdspGAAM=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.89.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-${platform}.tar.gz";
    hash = hashes.${stdenv.hostPlatform.system}
      or (throw "missing hash for ${stdenv.hostPlatform.system}");
  };

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    tar -xzf "$src"
    install -Dm755 "codex-${platform}" "$out/bin/codex"
    runHook postInstall
  '';

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  postFixup = ''
    wrapProgram $out/bin/codex --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^rust-v(\\d+\\.\\d+\\.\\d+)$"
      ];
    };
  };

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    maintainers = with lib.maintainers; [
      malo
      delafthi
    ];
    platforms = lib.platforms.unix;
  };
})
