{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "7.2.135";
  targets = {
    aarch64-darwin = {
      asset = "darwin_aarch64";
      hash = "sha256-xfbnhc91aMF31cMap1w4nEuxsd7p4BM4h7m84yAEdd0=";
    };
    x86_64-darwin = {
      asset = "darwin_amd64";
      hash = "sha256-0XHgC0fADAfjTFP8k/m3G42yPvI0lsO2mUA4lA8xnEw=";
    };
    aarch64-linux = {
      asset = "linux_aarch64";
      hash = "sha256-qIVFyYWDW8sDgSfAUKz5LmcrNU3RH4kd22WNVtJU1t0=";
    };
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256-9eXM8PP+rTou4IjLN6aemW8FsztH8Ra0NR2/0dQiQkE=";
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
