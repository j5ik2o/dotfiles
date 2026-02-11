{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "6.8.11";
  targets = {
    aarch64-darwin = {
      asset = "darwin_arm64";
      hash = "sha256-SpRF/Ce1oNs6MS7hcg9BEXPfdp4Kxp5EA6h9xKiyEkI=";
    };
    x86_64-darwin = {
      asset = "darwin_amd64";
      hash = "sha256-IFOa57sGxykR1YOSYPi52kn3E2ueIookQIh9BJPiKxk=";
    };
    aarch64-linux = {
      asset = "linux_arm64";
      hash = "sha256-WPcPziGlXPCIICG/lD6ap9W+kSdeQzzYs1s90gtHxtI=";
    };
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256-rc0pmaXwoR9fKlIIO98F7LD78omw4JPYFtTyaCL+70g=";
    };
  };
  target =
    targets.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for cliproxyapi: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "cliproxyapi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_${target.asset}.tar.gz";
    hash = target.hash;
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
    ln -s $out/bin/cli-proxy-api $out/bin/cliproxyapi
    install -Dm644 config.example.yaml $out/share/cliproxyapi/config.example.yaml

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI/Gemini/Claude/Codex compatible API proxy for CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = licenses.mit;
    mainProgram = "cliproxyapi";
    platforms = builtins.attrNames targets;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
