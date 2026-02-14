{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "6.8.15";
  targets = {
    aarch64-darwin = {
      asset = "darwin_arm64";
      hash = "sha256-r+po/X5Wuzvreh6r5HFLgKwl15ZmXhXfBB2EymYE54c=";
    };
    x86_64-darwin = {
      asset = "darwin_amd64";
      hash = "sha256-ysRRifyjsQhmvbRPd3mfbVFUOhnlZpfaHmxc5tknHjk=";
    };
    aarch64-linux = {
      asset = "linux_arm64";
      hash = "sha256-umLS2CGZtknFlfV8x/Q9IIyYhTjfmJ6SkygCjJgr1/I=";
    };
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256-7YeeQMsz5y+J9EgCEP+dl4BGJj5pQEP8hiLpPudQpZA=";
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
