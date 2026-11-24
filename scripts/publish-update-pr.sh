#!/usr/bin/env bash
# 定期更新のコミット (HEAD) を更新用の枝に載せ、開いた PR が無ければ作る。
#
# 使い方: publish-update-pr.sh <branch> <base> <title>
#
# 前提: HEAD は origin/<base> の上に作った 1 コミットで、件名は <title>。
# origin の枝は取得済み (actions/checkout の fetch-depth: 0)。
# gh は GH_TOKEN の権限で動く。GITHUB_TOKEN で作った PR では
# pull_request の CI が起動しないので、呼び出し側は PAT を渡す。
#
# 枝の扱い:
# - 枝が無い: push する。
# - 枝が自動コミットだけで、今の <base> へ競合なくマージでき、その結果が HEAD と
#   同じ tree: push しない。<base> に無関係の変更が入っただけで CI を起動し直さない。
# - 枝が自動コミットだけで、競合するか中身が違う: 今の <base> の上に作り直して push する。
#   確かめた先端から動いていれば push は拒否される (--force-with-lease)。
# - 枝に自動コミット以外が載っている (人の修正など): 上書きせず警告する。

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <branch> <base> <title>" >&2
  exit 2
fi

branch=$1
base=$2
title=$3
remote_ref="refs/remotes/origin/${branch}"
base_ref="refs/remotes/origin/${base}"

if tip=$(git rev-parse --verify --quiet "${remote_ref}"); then
  extra=$(git log --format=%s "${base_ref}..${tip}")
  if [ -n "${extra}" ] && [ "${extra}" != "${title}" ]; then
    echo "::warning::origin/${branch} has commits other than '${title}'; leaving it as is"
  elif merged=$(git merge-tree --write-tree "${base_ref}" "${tip}") &&
    [ "${merged}" = "$(git rev-parse 'HEAD^{tree}')" ]; then
    echo "origin/${branch} already has this update"
  else
    git push --force-with-lease="refs/heads/${branch}:${tip}" origin "HEAD:refs/heads/${branch}"
  fi
else
  git push origin "HEAD:refs/heads/${branch}"
fi

# 同じ名前の枝を持つフォークの PR は数えない。
pr=$(gh pr list --head "${branch}" --base "${base}" --state open \
  --json url,isCrossRepository --jq 'map(select(.isCrossRepository | not))[0].url // empty')
if [ -n "${pr}" ]; then
  echo "open PR: ${pr}"
else
  gh pr create --base "${base}" --head "${branch}" --title "${title}" \
    --body "Opened by the ${GITHUB_WORKFLOW:-update} workflow (run ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}). Merge after the required checks pass."
fi
