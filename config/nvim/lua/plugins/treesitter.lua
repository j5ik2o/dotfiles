return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
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
    },
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
    },
  },
}
