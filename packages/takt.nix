{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "takt";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "nrslib";
    repo = "takt";
    rev = "v${version}";
    hash = "sha256-6VeQxUODr8+XfFZ1wqnzK+Jhvs4UfWuMAtKfzMbLGa0=";
  };

  npmDepsHash = "sha256-9YPG+h4PBp+ttC08jn2HGXyQx867W1m24Zv1gKyDoqY=";

  meta = with lib; {
    description = "Task Agent Koordination Tool";
    homepage = "https://github.com/nrslib/takt";
    license = licenses.mit;
    mainProgram = "takt";
    platforms = platforms.unix;
  };
}
