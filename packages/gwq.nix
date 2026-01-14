{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gwq";
  version = "0.0.7";

  src = fetchFromGitHub {
    owner = "d-kuro";
    repo = "gwq";
    rev = "v${version}";
    hash = "sha256-CvfAxTd7/AK98TSJDM+iNJTUALMKMk8esXEn7Fuumik=";
  };

  vendorHash = "sha256-c1vq9yETUYfY2BoXSEmRZj/Ceetu0NkIoVCM3wYy5iY=";

  subPackages = [ "cmd/gwq" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = "Git worktree manager for efficient parallel development";
    homepage = "https://github.com/d-kuro/gwq";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "gwq";
  };
}
