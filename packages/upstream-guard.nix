# ボットとワーカーの環境で、禁止の宛先へのマージと push を実行前に止める PreToolUse フック。
# 判定は scripts/upstream_guard.py、使い方と外し方は docs/upstream-guard.md。
{ writers }:

# lint は scripts/lint.sh の ruff が見るので、writers の flake8 は回さない
writers.writePython3Bin "upstream-guard" { doCheck = false; } (
  builtins.readFile ../scripts/upstream_guard.py
)
