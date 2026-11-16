{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  claude-code-proxy,
  claudecodexSrc,
}:

stdenvNoCC.mkDerivation {
  pname = "claudecodex";
  version = "unstable-1bd7ee0";

  src = claudecodexSrc;
  patches = [ ./claudecodex-gateway-discovery.patch ];

  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 claudecodex $out/bin/claudecodex
    wrapProgram $out/bin/claudecodex \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          claude-code-proxy
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "Launch Claude Code with GPT models through a local Codex proxy";
    homepage = "https://github.com/karem505/claudecodex";
    license = licenses.mit;
    mainProgram = "claudecodex";
    platforms = platforms.unix;
  };
}
