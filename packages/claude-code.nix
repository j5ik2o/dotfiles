{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  procps,
  bubblewrap,
  socat,
}:
let
  toolVersions = lib.importTOML ./ai-tools.toml;
  claude = toolVersions."claude-code";

  # Claude 公式のインストーラ (claude.ai/install.sh) が参照している配布先
  officialBaseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x64";
  };

in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "claude-code";
  version = claude.version;

  src = fetchurl {
    url = "${officialBaseUrl}/${finalAttrs.version}/${platformMap.${stdenvNoCC.hostPlatform.system}}/claude";
    hash = claude.hashes.${stdenvNoCC.hostPlatform.system};
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  # 公式配布バイナリは自己完結型なので加工しない
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/claude

    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --unset DEV \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
          ]
          ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }

    runHook postInstall
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      adeci
      malo
      markus1189
      omarjatoi
      xiaoxiangmoe
    ];
    mainProgram = "claude";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
