{
  config,
  pkgs,
  lib,
  self,
  ...
}:

let
  piAgentDir = "${config.home.homeDirectory}/.pi/agent";
  piConfigDir = "${self}/config/pi/agent";

  # pi 本体とプラグインが起動中に書き換えるファイル。
  # Nix store へのリンクにすると保存できない (pi-btw / pi-statusline は
  # 一時ファイル + rename で保存するためリンク自体も置き換わる) ので、
  # activation で実体をコピーして書き込み可能な通常ファイルにする。
  # リポジトリ側は配布元の初期値であり、make apply のたびに上書きされる。
  mutableFiles = [
    "settings.json"
    "pi-btw.json"
    "pi-statusline.json"
  ];

  copyMutableFiles = lib.concatStringsSep "\n" (
    map (name: ''
      if [ -f "${piAgentDir}/${name}" ] && ! cmp -s "${piAgentDir}/${name}" "${piConfigDir}/${name}"; then
        mkdir -p "${piAgentDir}/.dotfiles-backup"
        cp -f "${piAgentDir}/${name}" "${piAgentDir}/.dotfiles-backup/${name}"
      fi
      cp -f "${piConfigDir}/${name}" "${piAgentDir}/${name}"
    '') mutableFiles
  );

  # npm:pi-subagents が subagent ツールを提供する。以前手動で置いた
  # extensions/subagent/ が残っているとツール名が二重登録されて pi が
  # 起動できなくなるため、見つけたら退避する。
  quarantineLegacySubagent = ''
    if [ -e "${piAgentDir}/extensions/subagent" ]; then
      mkdir -p "${piAgentDir}/.dotfiles-backup/subagent-legacy"
      _pi_legacy_target="${piAgentDir}/.dotfiles-backup/subagent-legacy/subagent"
      if [ -e "$_pi_legacy_target" ]; then
        _pi_legacy_target="$_pi_legacy_target.$(date +%Y%m%d%H%M%S)"
      fi
      mv "${piAgentDir}/extensions/subagent" "$_pi_legacy_target"
    fi
  '';

  # pi は agents/*.md を読むだけなので、opencode と同じく Nix store へのリンクで管理する。
  agentFiles = lib.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
      builtins.readDir ./../../config/pi/agent/agents
    )
  );
in
{
  # 読み取り専用の設定は Nix 管理 (opencode の xdg.configFile と同じ考え方)
  home.file = {
    ".pi/agent/models.json".source = "${piConfigDir}/models.json";
    ".pi/agent/extensions/content-guard.ts".source = "${piConfigDir}/extensions/content-guard.ts";
  }
  // lib.listToAttrs (
    map (name: {
      name = ".pi/agent/agents/${name}";
      value.source = "${piConfigDir}/agents/${name}";
    }) agentFiles
  );

  home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail
    mkdir -p "${piAgentDir}"
    ${quarantineLegacySubagent}
    ${copyMutableFiles}
  '';
}
