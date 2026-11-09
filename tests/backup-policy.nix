# 管理対象ファイルの扱いを評価時に検証する (force = true とバックアップ未設定を禁止)
{ lib, flake }:

let
  # darwin 側は home-manager.backupFileExtension が環境変数として渡され、
  # standalone 側は home.backupFileExtension が activation 内で展開される。
  findingsFor =
    name: home: systemBackupExtension:
    let
      forced = map (v: v.target) (lib.filter (v: v.enable && v.force) (lib.attrValues home.file));
      backupExtension =
        if home.backupFileExtension != null then home.backupFileExtension else systemBackupExtension;
    in
    lib.optional (forced != [ ])
      "${name}: force = true の管理対象 ${toString (lib.length forced)} 件: ${lib.concatStringsSep ", " forced}"
    ++ lib.optional (backupExtension == null) "${name}: バックアップ拡張子が未設定";

  standaloneFindings = lib.mapAttrsToList (
    name: hm: findingsFor name hm.config.home null
  ) flake.homeConfigurations;

  darwinFindings = lib.concatLists (
    lib.mapAttrsToList (
      name: darwin:
      lib.mapAttrsToList (
        user: hm: findingsFor "${name}/${user}" hm.home darwin.config.home-manager.backupFileExtension
      ) darwin.config.home-manager.users
    ) flake.darwinConfigurations
  );
in
lib.concatLists standaloneFindings ++ lib.concatLists darwinFindings
