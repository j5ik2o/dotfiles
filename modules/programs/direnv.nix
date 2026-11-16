{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================
  # direnv 設定
  # 開発環境の自動切り替え
  # ============================================================
  programs.direnv = {
    enable = true;
    # Zsh は sheldon で初期化するため無効化
    enableZshIntegration = false;

    # nix-direnv を使用 (キャッシュ機能付き)
    nix-direnv.enable = true;

    # direnv 設定
    config = {
      global = {
        # ログ出力を抑制
        hide_env_diff = true;
        # 許可リストのキャッシュ時間 (秒)
        warn_timeout = "30s";
      };
      whitelist = {
        # 自動的に許可するディレクトリプレフィックス
        prefix = [
          "~/Projects"
          "~/Developer"
          "~/Sources"
          "~/work"
        ];
        # 完全パスで許可
        exact = [
          "~/.config/home-manager"
        ];
      };
    };

    # direnv の標準ライブラリ拡張
    stdlib = ''
      # ============================================================
      # カスタム direnv ライブラリ
      # ============================================================

      # use_nix_shell: 従来の shell.nix サポート
      use_nix_shell() {
        eval "$(nix-shell --run 'direnv dump')"
      }

      # use_flake: flake ベースの開発環境 (nix-direnv が提供)
      # 既に nix-direnv で提供されているため追加不要

      # layout_poetry: Python Poetry プロジェクト用
      layout_poetry() {
        if [[ ! -f pyproject.toml ]]; then
          log_error 'No pyproject.toml found. Use `poetry init` to create one first.'
          exit 2
        fi

        local VENV=$(dirname $(poetry run which python))
        export VIRTUAL_ENV=$(dirname "$VENV")
        export POETRY_ACTIVE=1
        PATH_add "$VENV"
      }

      # layout_pdm: Python PDM プロジェクト用
      layout_pdm() {
        if [[ ! -f pyproject.toml ]]; then
          log_error 'No pyproject.toml found.'
          exit 2
        fi

        local VENV=$(pdm venv --path 2>/dev/null || pdm info --packages)
        export VIRTUAL_ENV="$VENV"
        PATH_add "$VENV/bin"
      }

      # layout_node: Node.js プロジェクト用
      layout_node() {
        PATH_add node_modules/.bin
      }

      # use_mise: mise (旧 rtx) 統合
      use_mise() {
        direnv_load mise direnv exec
      }

      # use_asdf: asdf 統合
      use_asdf() {
        source_env "$(asdf direnv envrc)"
      }

      # layout_rust: Rust プロジェクト用
      layout_rust() {
        export CARGO_HOME="$PWD/.cargo"
        export RUSTUP_HOME="$PWD/.rustup"
        PATH_add "$CARGO_HOME/bin"
      }

      # layout_go: Go プロジェクト用
      layout_go() {
        export GOPATH="$PWD/.go"
        PATH_add "$GOPATH/bin"
      }

      # dotenv: .env ファイルの読み込み
      dotenv() {
        local envfile="''${1:-.env}"
        if [[ -f "$envfile" ]]; then
          watch_file "$envfile"
          while IFS='=' read -r key value; do
            # コメントと空行をスキップ
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            # クォートを除去
            value="''${value%\"}"
            value="''${value#\"}"
            export "$key=$value"
          done < "$envfile"
        fi
      }

      # dotenv_if_exists: .env があれば読み込み
      dotenv_if_exists() {
        local envfile="''${1:-.env}"
        if [[ -f "$envfile" ]]; then
          dotenv "$envfile"
        fi
      }

      # watch_file_recursive: ディレクトリ内のファイルを再帰的に監視
      watch_file_recursive() {
        local dir="''${1:-.}"
        find "$dir" -type f | while read -r file; do
          watch_file "$file"
        done
      }

      # source_env_if_exists: ファイルがあれば読み込み
      source_env_if_exists() {
        if [[ -f "$1" ]]; then
          source_env "$1"
        fi
      }

      # use_docker_machine: Docker Machine 環境設定
      use_docker_machine() {
        local env="''${1:-default}"
        eval "$(docker-machine env "$env")"
      }

      # use_aws_profile: AWS プロファイル切り替え
      use_aws_profile() {
        export AWS_PROFILE="$1"
        export AWS_DEFAULT_PROFILE="$1"
      }

      # use_gcp_project: GCP プロジェクト切り替え
      use_gcp_project() {
        export GOOGLE_CLOUD_PROJECT="$1"
        export GCLOUD_PROJECT="$1"
      }

      # use_k8s_context: Kubernetes コンテキスト切り替え
      use_k8s_context() {
        export KUBECONFIG="''${KUBECONFIG:-$HOME/.kube/config}"
        kubectl config use-context "$1" >/dev/null 2>&1
      }
    '';
  };

  # ============================================================
  # direnv 用 .envrc テンプレート
  # ~/.config/direnv/templates/ に配置
  # ============================================================
  home.file.".config/direnv/templates/flake.envrc".text = ''
    # Nix Flake ベースの開発環境
    use flake
    dotenv_if_exists
  '';

  home.file.".config/direnv/templates/python-poetry.envrc".text = ''
    # Python Poetry プロジェクト
    layout poetry
    dotenv_if_exists
  '';

  home.file.".config/direnv/templates/node.envrc".text = ''
    # Node.js プロジェクト
    layout node
    dotenv_if_exists
  '';

  home.file.".config/direnv/templates/rust.envrc".text = ''
    # Rust プロジェクト
    use flake
    dotenv_if_exists
  '';

  home.file.".config/direnv/templates/go.envrc".text = ''
    # Go プロジェクト
    use flake
    dotenv_if_exists
  '';
}
