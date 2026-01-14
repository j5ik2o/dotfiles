-- ============================================================
-- 基本オプション
-- ============================================================

local opt = vim.opt

-- リーダーキー
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 行番号
opt.number = true
opt.relativenumber = false

-- マウス
opt.mouse = "a"

-- モード非表示（lualineで表示するため）
opt.showmode = false

-- クリップボード
opt.clipboard = "unnamedplus"

-- インデント
opt.breakindent = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Undo
opt.undofile = true

-- 検索
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- サイン列
opt.signcolumn = "yes"

-- 更新時間
opt.updatetime = 250
opt.timeoutlen = 300

-- ファイル自動再読み込み
opt.autoread = true

-- 分割
opt.splitright = true
opt.splitbelow = true

-- 空白文字表示
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- インクリメンタル置換
opt.inccommand = "split"

-- カーソル行
opt.cursorline = true

-- スクロールオフセット
opt.scrolloff = 10

-- 折りたたみ（treesitter）
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldenable = false

-- 補完
opt.completeopt = "menu,menuone,noselect"

-- ターミナルカラー
opt.termguicolors = true

-- ポップアップ
opt.pumheight = 10
opt.pumblend = 10

-- コマンドライン
opt.cmdheight = 1
opt.laststatus = 3
