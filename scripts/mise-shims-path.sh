# shellcheck shell=sh
# .zshenv に埋め込み、zsh を起こすたびに読む。mise の shims を PATH に置く。
#
# shims がすでに PATH にあれば何もしない。親プロセスが PATH の先頭に置いたもの
# （たとえば共有の TAKT の bin）を、非対話の `zsh -c` が shims の後ろへ押しやらない
# ためである。PATH に無いとき（launchd や cron の素の PATH）だけ先頭に足し、
# /usr/bin の同名コマンドより mise のツールを優先させる。
#
# 読み手のシェルに残るので、変数は _mise_shims 一つだけ使い、最後に消す。

_mise_shims="$HOME/.local/share/mise/shims"
case ":${PATH-}:" in
  *":$_mise_shims:"*) ;;
  *) export PATH="$_mise_shims${PATH:+:$PATH}" ;;
esac
unset _mise_shims
