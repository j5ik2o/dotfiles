{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.7.1";
  targets = {
    aarch64-darwin = {
      asset = "macos-aarch64";
      hash = "sha256-FvRlPwSR6h59K0a1sCVC8Y4bguiNqvnikAVy5btjTfg=";
    };
    x86_64-darwin = {
      asset = "macos-x86_64";
      hash = "sha256-V4D6B9u5p4155S0guGphAT9sugJmfyC2z4lmMBUJCEY=";
    };
    aarch64-linux = {
      asset = "linux-aarch64";
      hash = "sha256-PXV6wwxjHnncRQOMPsxkI/4TqJ+c/6D0Fa7dLCfxV2w=";
    };
    x86_64-linux = {
      asset = "linux-x86_64";
      hash = "sha256-uWWsr/wsIvVLbmxkr3z46Yo/SsJiJjCgWZxnpLnYplQ=";
    };
  };
  target =
    targets.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for herdr: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-${target.asset}";
    hash = target.hash;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/herdr

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = licenses.agpl3Only;
    mainProgram = "herdr";
    platforms = builtins.attrNames targets;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
