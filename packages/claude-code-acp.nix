{
  lib,
  buildNpmPackage,
  fetchurl,
}:

let
  version = "0.1.1";
in
buildNpmPackage {
  pname = "claude-code-acp";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/claude-code-acp/-/claude-code-acp-${version}.tgz";
    hash = "sha256-ihRnjbzdTDrEcW4JvJpYNq8m5W9Wj1PDVNsIEUGymZs=";
  };

  postPatch = ''
    cp ${./claude-code-acp-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-d1uhbixSt84XSl+tO2X12ST7Xi/fhzkpHKtsmJ4GMIw=";
  dontNpmBuild = true;

  postFixup = ''
    ln -s $out/bin/cc-acp $out/bin/claude-code-acp
  '';

  meta = {
    description = "Claude Code agent for ACP (Agent Client Protocol)";
    homepage = "https://github.com/carlrannaberg/cc-acp";
    license = lib.licenses.mit;
    mainProgram = "claude-code-acp";
    platforms = lib.platforms.unix;
  };
}
