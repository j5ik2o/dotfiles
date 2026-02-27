{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

let
  version = "0.3.6";
  targets = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-s5A/FDmEQ28kGyQniV5entMAdjeLIR+/oC/DiJocw6k=";
    };
    x86_64-darwin = {
      asset = "darwin-x64";
      hash = "sha256-daJTcCypYbZGqQa2Z3BshaeoxrdtMxTJSUXgDbILu/4=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-XDmdcQHoEBqq1Z6OGrRa96/oXRNpCnPr4P0pa40wPEo=";
    };
    x86_64-linux = {
      asset = "linux-x64";
      hash = "sha256-X87wVqXBjaZaPz/ER/ExyV5EqZqE7IudlRF2cOFL04A=";
    };
  };
  target =
    targets.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported system for coderabbit: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "coderabbit";
  inherit version;

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-${target.asset}.zip";
    hash = target.hash;
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 coderabbit $out/bin/coderabbit

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-powered code review CLI by CodeRabbit";
    homepage = "https://www.coderabbit.ai/cli";
    license = licenses.unfree;
    mainProgram = "coderabbit";
    platforms = builtins.attrNames targets;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
