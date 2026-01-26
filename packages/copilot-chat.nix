{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

let
  rev = "07dcc188bc488b2dafa9324bd42088640bee3d19";
in
vimUtils.buildVimPlugin {
  pname = "CopilotChat.nvim";
  version = "unstable-${lib.strings.substring 0 7 rev}";

  src = fetchFromGitHub {
    owner = "CopilotC-Nvim";
    repo = "CopilotChat.nvim";
    inherit rev;
    hash = "sha256-MKGkcgyIwRDQs31yqaNrTvJOJlL5FErQjbINeJPlkiQ=";
  };

  meta = {
    description = "Copilot Chat for Neovim";
    homepage = "https://github.com/CopilotC-Nvim/CopilotChat.nvim";
    license = lib.licenses.mit;
  };
}
