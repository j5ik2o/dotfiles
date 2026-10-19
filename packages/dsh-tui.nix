{
  lib,
  buildNpmPackage,
  runCommand,
  nodejs_24,
  bash,
  coreutils,
  jq,
  stdenv,
  autoPatchelfHook,
}:

buildNpmPackage {
  pname = "dsh-tui";
  version = "0.9.0";
  nodejs = nodejs_24;

  src = runCommand "dsh-tui-source" { } ''
    mkdir -p $out
    cp ${./dsh-tui-package.json} $out/package.json
    cp ${./dsh-tui-lock.json} $out/package-lock.json
  '';

  npmDepsHash = "sha256-ku1LLRkyfJ7UD7zMjjZkcGRytcZLtW0qQRX4H/IpIwY=";
  dontNpmBuild = true;
  # npm 公開版のビルド済み JS / native addon を利用し、追加取得を行わない。
  npmRebuildFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # Nix 版 Node の getter は native addon の機械語パターンと一致しない。
  # Cordis loader と同じ --expose-internals の経路を app-boot にも使わせる。
  # https://github.com/deepseek-ai/deepseek-harness/discussions/690
  postConfigure = ''
    # モデル選択を実行中の会話とチャット表示にも反映する。
    patch --fuzz=0 -p1 -d node_modules/@tomowang/dsh-tui < ${./dsh-tui-model-selection.patch}
    patch --fuzz=0 -p1 -d node_modules/@tomowang/dsh-tui < ${./dsh-tui-effort.patch}

    substituteInPlace node_modules/@deepseek-ai/dsh-app-boot/lib/index.js \
      --replace-fail 'const addon = createRequire(import.meta.url)("node-addon-require-builtin");' \
      'const addon = process.execArgv.includes("--expose-internals") ? { requireBuiltin: createRequire(import.meta.url) } : createRequire(import.meta.url)("node-addon-require-builtin");'

    # OpenCode Go が要求する会話ごとのセッション ID を全 API 形式で送る。
    substituteInPlace node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js \
      --replace-fail 'headers: requestHeaders(profile.headers)' \
      'headers: requestHeaders({ ...profile.headers, ...(options.provider === "opencode-go" && options.sessionId !== void 0 ? { "x-opencode-session": String(options.sessionId) } : {}) })'

    # 選択したアカウントのレコードへ直接読み書きし、更新トークンも同じ場所に保存する。
    # 環境変数は起動時に固定するので、別プロセスで選択を変えても実行中の認証は変わらない。
    substituteInPlace node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js \
      --replace-fail 'return credentialKey(RECORD_SCOPE, providerId);' \
      'return credentialKey(RECORD_SCOPE, providerId === "openai-codex" && process.env.DSH_CODEX_CREDENTIAL_ID ? process.env.DSH_CODEX_CREDENTIAL_ID : providerId);' \
      --replace-fail 'if (credentialKeyScope(entry.key) !== "llm-pi-ai") continue;' \
      'if (credentialKeyScope(entry.key) !== "llm-pi-ai" || (credentialKeyId(entry.key).startsWith("openai-codex-") && credentialKeyId(entry.key) !== process.env.DSH_CODEX_CREDENTIAL_ID)) continue;' \
      --replace-fail 'providerId: credentialKeyId(entry.key),' \
      'providerId: credentialKeyId(entry.key) === process.env.DSH_CODEX_CREDENTIAL_ID ? "openai-codex" : credentialKeyId(entry.key),'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/dsh-tui $out/bin
    cp -r node_modules $out/lib/dsh-tui/
    mkdir -p $out/lib/dsh-tui/node_modules/dsh-tui-providers
    cp ${./dsh-tui-providers.yml} $out/lib/dsh-tui/node_modules/dsh-tui-providers/cordis.patch.yml
    cat > $out/lib/dsh-tui/node_modules/dsh-tui-providers/package.json <<'EOF'
    {
      "name": "dsh-tui-providers",
      "version": "1.0.0",
      "private": true,
      "dsh": { "bundle": { "patch": "cordis.patch.yml" } }
    }
    EOF
    # 他プラットフォームの PTY バイナリは不要。Darwin の ELF 検査も避ける。
    find $out/lib/dsh-tui/node_modules/node-pty/prebuilds -mindepth 1 -maxdepth 1 \
      ! -name '${if stdenv.hostPlatform.isDarwin then "darwin" else "linux"}-${
        if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
      }' \
      -exec rm -rf {} +
    cat > $out/lib/dsh-tui/profile.json <<'EOF'
    {
      "name": "dsh-tui-profile",
      "private": true,
      "dependencies": { "@tomowang/dsh-tui": "0.9.0" },
      "dsh": {
        "profile": {
          "bundles": ["@deepseek-ai/dsh-base", "@tomowang/dsh-tui", "dsh-web-search-searxng", "dsh-tui-providers"]
        }
      }
    }
    EOF

    cp ${./dsh-tui-login.mjs} $out/lib/dsh-tui/login.mjs
    cp ${./dsh-tui-models.mjs} $out/lib/dsh-tui/models.mjs

    # DSH_HOME が既に設定されていても既存 CLI の設定・認証・履歴を使わない。
    # manifest と依存は毎回 Nix 管理の実体へリンクし、ユーザーの patch は保持する。
    cat > $out/bin/dsh-tui <<EOF
    #!${bash}/bin/bash
    set -euo pipefail
    export DSH_HOME="\$HOME/.dsh-tui"
    if [[ "\''${1:-}" == --login || "\''${1:-}" == --account || "\''${1:-}" == --accounts ]]; then
      exec ${nodejs_24}/bin/node "$out/lib/dsh-tui/login.mjs" "\$@"
    fi
    DSH_CODEX_CREDENTIAL_ID="\$(${nodejs_24}/bin/node "$out/lib/dsh-tui/login.mjs" --current)"
    export DSH_CODEX_CREDENTIAL_ID
    account_patch=""
    case "\''${1:-}" in
      --version|-V|--help|-h|--dump-default-config|--dump-config-schema) ;;
      *) account_patch="\$(${nodejs_24}/bin/node "$out/lib/dsh-tui/login.mjs" --prepare)" ;;
    esac
    ${coreutils}/bin/mkdir -p "\$DSH_HOME/profiles/tui"
    ${coreutils}/bin/ln -sfnT "$out/lib/dsh-tui/profile.json" "\$DSH_HOME/profiles/tui/package.json"
    ${coreutils}/bin/ln -sfnT "$out/lib/dsh-tui/node_modules" "\$DSH_HOME/profiles/tui/node_modules"
    # 認証は実行時に既存の OpenCode から読み、値を Nix store に保存しない。
    auth_file="\''${XDG_DATA_HOME:-\$HOME/.local/share}/opencode/auth.json"
    if [[ -z "\''${OPENCODE_GO_API_KEY:-}" && -r "\$auth_file" ]]; then
      OPENCODE_GO_API_KEY="\$(${jq}/bin/jq -r '."opencode-go".key // empty' "\$auth_file")"
      export OPENCODE_GO_API_KEY
    fi
    # ログイン済みローカル Ollama ではこの値は使われないが、SDK が要求する。
    export DSH_OLLAMA_API_KEY="\''${DSH_OLLAMA_API_KEY:-ollama}"
    # DGX Spark の TensorFold は鍵を確かめないが、SDK が値を要求する。
    export DSH_TENSORFOLD_API_KEY="\''${DSH_TENSORFOLD_API_KEY:-tensorfold}"
    # ウェブ検索は NAS の SearXNG を使う。行の設定は丸ごと置き換わるため、利用者が
    # web-search-searxng の行を上書きしても宛先が消えないよう、環境変数で渡す。
    export SEARXNG_URL="\''${SEARXNG_URL:-http://10.0.1.30:8888}"
    patch_args=()
    if [[ -n "\$account_patch" ]]; then
      patch_args=(--patch "\$account_patch")
    fi
    exec ${nodejs_24}/bin/node --expose-internals "$out/lib/dsh-tui/node_modules/@deepseek-ai/dsh/lib/bin.js" --profile tui "\''${patch_args[@]}" "\$@"
    EOF
    chmod +x $out/bin/dsh-tui

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    run_dsh_tui() {
      env -i HOME="$TMPDIR/dsh-tui-check" PATH="${
        lib.makeBinPath [
          bash
          coreutils
        ]
      }:/usr/bin:/bin" \
        DSH_HOME="$TMPDIR/existing-dsh" DSH_TELEMETRY_DISABLED=1 \
        "$out/bin/dsh-tui" "$@"
    }
    test "$(run_dsh_tui --version)" = "0.1.7-rc.2"
    run_dsh_tui --dump-config > tui-config.yml
    grep -q "name: '@tomowang/dsh-tui'" tui-config.yml
    grep -q 'displayName: OpenCode Go' tui-config.yml
    grep -q 'displayName: OpenAI Codex (ChatGPT subscription)' tui-config.yml
    grep -q 'baseURL: http://localhost:11434/v1' tui-config.yml
    grep -q 'baseURL: http://10.0.1.60:8000/v1' tui-config.yml
    grep -q 'provider: opencode-go' tui-config.yml
    grep -q "name: dsh-web-search-searxng" tui-config.yml
    grep -q 'searchProvider: searxng' tui-config.yml
    grep -q 'SEARXNG_URL:-http://10.0.1.30:8888' "$out/bin/dsh-tui"
    run_dsh_tui --help > tui-help.txt
    grep -q 'Interactive terminal session' tui-help.txt
    run_dsh_tui --login --help > login-help.txt
    grep -q 'ChatGPT' login-help.txt
    ${nodejs_24}/bin/node ${./dsh-tui-accounts-check.mjs} "$out/lib/dsh-tui" "$out/bin/dsh-tui"
    ${nodejs_24}/bin/node ${./dsh-tui-models-check.mjs} "$out/lib/dsh-tui"
    ${nodejs_24}/bin/node ${./dsh-tui-model-selection-check.mjs} "$out/lib/dsh-tui"
    ${nodejs_24}/bin/node ${./dsh-tui-effort-check.mjs} "$out/lib/dsh-tui"
    test ! -e "$TMPDIR/existing-dsh"

    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "DeepSeek Harness TUI with a pinned compatible CLI and isolated home";
    homepage = "https://github.com/tomowang/dsh-tui";
    license = licenses.mit;
    mainProgram = "dsh-tui";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
