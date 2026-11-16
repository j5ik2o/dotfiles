{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

# DS Bot の macOS デスクトップアプリ。DeepSeek Harness と ds-bot プラグインを
# 同梱する配布物で、Homebrew cask は無い。署名・公証が無いのでハッシュで固定する。
# macOS 版は自己更新せず、新版があると通知するだけ（README の Install 参照）。
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ds-bot-app";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/Fei2411/DS-Bot/releases/download/v${finalAttrs.version}/DS-Bot-${finalAttrs.version}-mac-arm64.zip";
    hash = "sha256-9erZJaQdB9a2PTNQuVWabye+7t91sNZ2wvrsbB8zPvk=";
  };

  nativeBuildInputs = [ unzip ];

  # 配布物は ad-hoc 署名済みで、shebang の書き換えや strip を行うと署名が壊れる。
  # 中身をそのまま保つ。
  dontFixup = true;

  # zip は DS Bot.app をルートに含む。展開先で cd しない。
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    unzip -q "$src" -d unpacked
    mkdir -p $out/Applications
    # フレームワーク内のシンボリックリンクと実行属性を保つ。
    cp -R "unpacked/DS Bot.app" $out/Applications/

    runHook postInstall
  '';

  meta = {
    description = "DS Bot desktop app: a team of long-lived Bots for DeepSeek Harness";
    homepage = "https://github.com/Fei2411/DS-Bot";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
