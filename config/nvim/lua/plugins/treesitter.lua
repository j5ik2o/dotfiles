local uv = vim.uv or vim.loop
local plugin_dir = vim.env.NVIM_PLUGIN_DIR or ""
local grammars_dir = plugin_dir .. "/nvim-treesitter-grammars"
local stat = (plugin_dir ~= "") and uv.fs_stat(grammars_dir) or nil
local nix_grammars = stat and stat.type == "directory"

-- Nix 管理の場合はランタイムインストール不要。
-- 非 Nix 環境では ensure_installed でパーサーをコンパイルする。
local ensure = nix_grammars and {} or {
  -- システム言語
  "c",
  "cpp",
  "rust",
  "go",
  "zig",
  -- JVM言語
  "java",
  "scala",
  "kotlin",
  -- スクリプト言語
  "python",
  "ruby",
  "lua",
  "javascript",
  "typescript",
  "tsx",
  -- 関数型言語
  "haskell",
  "ocaml",
  -- マークアップ・設定
  "markdown",
  "markdown_inline",
  "html",
  "css",
  "json",
  "yaml",
  "toml",
  "xml",
  -- シェル・ツール
  "bash",
  "fish",
  "vim",
  "vimdoc",
  "regex",
  "diff",
  "git_config",
  "git_rebase",
  "gitcommit",
  "gitignore",
  -- その他
  "dockerfile",
  "sql",
  "graphql",
  "proto",
  "nix",
  "query",
}

return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = ensure,
    auto_install = not nix_grammars,
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
    },
  },
}
