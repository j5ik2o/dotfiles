{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  git,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
}:

stdenvNoCC.mkDerivation rec {
  pname = "multi-git-status";
  version = "2.3";

  src = fetchFromGitHub {
    owner = "fboender";
    repo = "multi-git-status";
    rev = version;
    hash = "sha256-DToyP6TD9up0k2/skMW3el6hNvKD+c8q2zWpk0QZGRA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 mgitstatus "$out/bin/mgitstatus"
    ln -s "$out/bin/mgitstatus" "$out/bin/multi-git-status"
    install -Dm644 mgitstatus.1 "$out/share/man/man1/mgitstatus.1"
    wrapProgram "$out/bin/mgitstatus" \
      --prefix PATH : ${lib.makeBinPath [
        git
        coreutils
        findutils
        gnugrep
        gnused
        gawk
      ]}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Show uncommitted, untracked, and unpushed changes in multiple Git repositories";
    homepage = "https://github.com/fboender/multi-git-status";
    license = licenses.mit;
    mainProgram = "mgitstatus";
    platforms = platforms.unix;
  };
}
