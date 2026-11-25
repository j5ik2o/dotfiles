#!/usr/bin/env python3
"""scripts/upstream_guard.py の判定の表。ネットワークも git も使わない。

nrslib 宛ての例は、ここで文字列として判定の関数に渡すだけで、実行はしない。
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from typing import ClassVar

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
)

import upstream_guard as ug

R = ug.Remote
REPOS: dict[str, ug.RepoInfo | None] = {
    # takt の実物と同じ形: origin は自分、upstream は上流で push の URL は DISABLED、set-default は origin
    "/w/takt": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",),
                ("https://github.com/j5ik2o/takt",),
                "base",
            ),
            "upstream": R(("https://github.com/nrslib/takt.git",), ("DISABLED",)),
        },
        default_push_remote="origin",
    ),
    "/w/takt/sub": None,  # 使わない（cd の解決の確認用）
    "/w/takt-unresolved": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",), ("https://github.com/j5ik2o/takt",)
            ),
            "upstream": R(
                ("https://github.com/nrslib/takt.git",),
                ("https://github.com/nrslib/takt.git",),
            ),
        },
        default_push_remote="origin",
    ),
    "/w/clone": ug.RepoInfo(
        remotes={
            "origin": R(
                ("git@github.com:NRSLib/takt.git",), ("git@github.com:NRSLib/takt.git",)
            )
        },
        default_push_remote="origin",
    ),
    "/w/pushurl": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/x",), ("ssh://git@github.com/nrslib/x.git",)
            )
        },
        default_push_remote="origin",
    ),
    "/w/pushdefault": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",), ("https://github.com/j5ik2o/takt",)
            ),
            "up": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            ),
        },
        default_push_remote="up",
    ),
    "/w/mine": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/dotfiles.git",),
                ("https://github.com/j5ik2o/dotfiles.git",),
            )
        },
        default_push_remote="origin",
    ),
    "/w/corp": ug.RepoInfo(
        remotes={
            "origin": R(
                ("git@github.com:ideo-plus/app.git",),
                ("git@github.com:ideo-plus/app.git",),
            )
        },
        default_push_remote="origin",
    ),
    "/w/alias": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",),
                ("https://github.com/j5ik2o/takt",),
                "base",
            ),
            "upstream": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            ),
        },
        default_push_remote="origin",
        git_aliases={"pu": "push upstream", "sh": "!git push upstream", "st": "status"},
    ),
    "/w/nodefault": ug.RepoInfo(
        remotes={
            "a": R(("https://github.com/j5ik2o/a",), ("https://github.com/j5ik2o/a",))
        },
        default_push_remote=None,
    ),
    "/w/notrepo": None,
    "--git-dir=/w/takt-unresolved/.git": None,
    "--git-dir=/w/clone/.git": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            )
        },
        default_push_remote="origin",
    ),
    "--git-dir=/w/mine/.git": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/dotfiles.git",),
                ("https://github.com/j5ik2o/dotfiles.git",),
            )
        },
        default_push_remote="origin",
    ),
}


class Repos(dict):
    def get(self, key, default=None):
        return super().get(key, default)


ENV = {"HOME": "/home/u", "PATH": "/usr/bin"}

D, A = "deny", "allow"

# (期待, コマンド, 作業ディレクトリ, 追加の環境変数)
CASES: list[tuple[str, str, str | None, dict[str, str]]] = [
    # --- gh pr merge -------------------------------------------------------
    (D, "gh pr merge 12 -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge -R nrslib/takt 12 --squash", "/w/mine", {}),
    (D, "gh pr merge --repo nrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge --repo=nrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge -Rnrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge 12 --repo github.com/nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge https://github.com/nrslib/takt/pull/12", "/w/mine", {}),
    (
        D,
        "gh pr merge https://github.com/NRSLIB/takt/pull/12 --auto --squash",
        "/w/mine",
        {},
    ),
    (D, "gh pr merge 12 --admin -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge 12 --auto", "/w/clone", {}),
    (D, "gh pr merge 12", "/w/takt-unresolved", {}),
    (D, "gh pr merge 12", "/w/mine", {"GH_REPO": "nrslib/takt"}),
    (D, "GH_REPO=nrslib/takt gh pr merge 12", "/w/mine", {}),
    (D, "env GH_REPO=nrslib/takt gh pr merge 12", "/w/mine", {}),
    (D, "export GH_REPO=nrslib/takt; gh pr merge 12", "/w/mine", {}),
    (D, "cd /w/clone && gh pr merge 12 -m", "/w/mine", {}),
    (D, "gh pr merge 12 -t 'subject' -b 'body' -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr update-branch 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr merge 12", "/w/takt", {}),  # set-default が origin（j5ik2o/takt）
    (A, "gh pr merge 12 -R j5ik2o/takt --squash --auto", "/w/takt", {}),
    (A, "gh pr merge https://github.com/j5ik2o/takt/pull/3", "/w/clone", {}),
    (A, "gh pr merge 3 --squash", "/w/corp", {}),
    (A, "gh pr merge 3", "/w/mine", {}),
    # --- gh pr / issue の書き込み以外 ---------------------------------------
    (A, "gh pr create -R nrslib/takt --draft --title t --body b", "/w/takt", {}),
    (A, "gh pr comment 12 -R nrslib/takt --body 'thanks'", "/w/mine", {}),
    (A, "gh pr ready 12 -R nrslib/takt", "/w/mine", {}),
    (
        A,
        "gh pr view 12 -R nrslib/takt --json mergeable,mergeStateStatus",
        "/w/mine",
        {},
    ),
    (A, "gh pr checks 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr diff 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr review 12 -R nrslib/takt --approve", "/w/mine", {}),
    (A, "gh pr view 12", "/w/takt-unresolved", {}),
    (A, "gh issue create -R nrslib/takt --title t --body b", "/w/mine", {}),
    (A, "gh issue comment 5 -R nrslib/takt --body 'merge later'", "/w/mine", {}),
    (A, "gh repo view nrslib/takt", "/w/mine", {}),
    (A, "gh pr list -R nrslib/takt --search 'is:merged'", "/w/mine", {}),
    # --- gh api（REST） ----------------------------------------------------
    (D, "gh api -X PUT repos/nrslib/takt/pulls/12/merge", "/w/mine", {}),
    (
        D,
        "gh api --method PUT /repos/nrslib/takt/pulls/12/merge -f merge_method=squash",
        "/w/mine",
        {},
    ),
    (D, "gh api repos/nrslib/takt/merges -f base=main -f head=feat", "/w/mine", {}),
    (
        D,
        "gh api -X POST repos/nrslib/takt/git/refs -f ref=refs/heads/x -f sha=abc",
        "/w/mine",
        {},
    ),
    (
        D,
        "gh api -X PATCH repos/nrslib/takt/git/refs/heads/main -f sha=abc -F force=true",
        "/w/mine",
        {},
    ),
    (D, "gh api -X DELETE repos/nrslib/takt/git/refs/heads/feat", "/w/mine", {}),
    (
        D,
        "gh api -X PUT repos/nrslib/takt/contents/README.md -f message=m -f content=Y29udGVudA==",
        "/w/mine",
        {},
    ),
    (D, "gh api -XPUT repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    (
        D,
        "gh api -X put https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        "/w/mine",
        {},
    ),
    (D, "gh api repos/nrslib/takt/releases -f tag_name=v1", "/w/mine", {}),
    (
        D,
        "gh api -X POST repos/nrslib/takt/merge-upstream -f branch=main",
        "/w/mine",
        {},
    ),
    (D, "gh api -X PUT 'repos/{owner}/{repo}/pulls/1/merge'", "/w/clone", {}),
    (D, "gh api -X PUT repos/$OWNER/takt/pulls/1/merge", "/w/mine", {}),
    (
        D,
        "gh api -X PUT repos/nrslib/takt/pulls/1/merge --input body.json",
        "/w/mine",
        {},
    ),
    (A, "gh api repos/nrslib/takt/pulls/12", "/w/mine", {}),
    (A, "gh api repos/nrslib/takt/contents/README.md", "/w/mine", {}),
    (A, "gh api -X GET repos/nrslib/takt/git/refs/heads/main", "/w/mine", {}),
    (
        A,
        "gh api repos/nrslib/takt/issues/5/comments -f body='push later'",
        "/w/mine",
        {},
    ),
    (A, "gh api -X PUT repos/j5ik2o/takt/pulls/12/merge", "/w/mine", {}),
    (
        A,
        "gh api -X POST repos/j5ik2o/takt/git/refs -f ref=refs/heads/x -f sha=abc",
        "/w/mine",
        {},
    ),
    (A, "gh api repos/nrslib/takt/pulls/1/reviews -f event=APPROVE", "/w/mine", {}),
    # --- gh api graphql ----------------------------------------------------
    (
        D,
        "gh api graphql -f query='mutation { enablePullRequestAutoMerge(input:{pullRequestId:\"PR_x\"}) { clientMutationId } }'",
        "/w/mine",
        {},
    ),
    (
        D,
        "gh api graphql -f query='mutation($id:ID!){ mergePullRequest(input:{pullRequestId:$id}){ clientMutationId } }' -f id=PR_x",
        "/w/mine",
        {},
    ),
    (
        D,
        "gh api graphql -f query='mutation { enqueuePullRequest(input:{pullRequestId:\"PR_x\"}) { clientMutationId } }'",
        "/w/mine",
        {},
    ),
    # 中身を読めないクエリは、コマンドの中に mutation の名前が無ければ通す（ボットのスレッドの解決を止めない）。
    # 読めるファイルの中に mutation があれば止める（Hook.test_graphql_query_file_is_read）
    (A, "gh api graphql -F query=@merge.graphql", "/w/mine", {}),
    (A, 'gh api graphql -f query="$(cat q.graphql)"', "/w/mine", {}),
    (D, 'gh api graphql -f query="$(echo mutation{mergePullRequest})"', "/w/mine", {}),
    (
        A,
        'gh api graphql -f query=\'{ repository(owner:"nrslib", name:"takt") { pullRequest(number:1) { mergeable } } }\'',
        "/w/mine",
        {},
    ),
    # --- gh repo sync / release / repo delete ------------------------------
    (D, "gh repo sync nrslib/takt", "/w/mine", {}),
    (D, "gh repo sync nrslib/takt --source j5ik2o/takt --force", "/w/mine", {}),
    (A, "gh repo sync j5ik2o/takt --source nrslib/takt", "/w/mine", {}),
    (A, "gh repo sync", "/w/takt", {}),
    (D, "gh release create v1.0.0 -R nrslib/takt --notes x", "/w/mine", {}),
    (D, "gh release upload v1 dist.tgz", "/w/clone", {}),
    (D, "gh release delete v1 -R nrslib/takt -y", "/w/mine", {}),
    (A, "gh release view v1 -R nrslib/takt", "/w/mine", {}),
    (A, "gh release create v1 -R j5ik2o/takt --notes x", "/w/mine", {}),
    (D, "gh repo delete nrslib/takt --yes", "/w/mine", {}),
    # --- git push ----------------------------------------------------------
    (
        D,
        "git push upstream main",
        "/w/takt",
        {},
    ),  # push の URL は DISABLED でも fetch が上流
    (D, "git push upstream HEAD:refs/heads/x --force", "/w/takt", {}),
    (D, "git push https://github.com/nrslib/takt.git main", "/w/mine", {}),
    (
        D,
        "git push https://x-access-token:abc@github.com/nrslib/takt main",
        "/w/mine",
        {},
    ),
    (D, "git push git@github.com:nrslib/takt.git HEAD", "/w/mine", {}),
    (D, "git push ssh://git@github.com/NrsLib/takt main", "/w/mine", {}),
    (D, "git push github.com:nrslib/takt main", "/w/mine", {}),
    (D, "git push", "/w/clone", {}),
    (D, "git push origin --tags", "/w/clone", {}),
    (D, "git push --mirror origin", "/w/clone", {}),
    (D, "git push --delete origin feat", "/w/clone", {}),
    (D, "git push origin", "/w/pushurl", {}),  # fetch は自分、push の URL だけ上流
    (D, "git push", "/w/pushdefault", {}),  # remote.pushDefault が上流
    (D, "git -C /w/takt push upstream main", "/w/mine", {}),
    (D, "git -C ../takt push upstream main", "/w/mine", {}),
    (D, "git -C /w -C takt push upstream", "/w/mine", {}),
    (D, "git --git-dir=/w/clone/.git push origin main", "/w/mine", {}),
    (D, "git --git-dir /w/clone/.git push", "/w/mine", {}),
    (D, "GIT_DIR=/w/clone/.git git push", "/w/mine", {}),
    (D, "cd /w/takt && git push upstream", "/w/mine", {}),
    (D, "cd ../takt; git push upstream", "/w/mine", {}),
    (D, "git push --repo=upstream", "/w/takt", {}),
    (D, "git push -o ci.skip upstream main", "/w/takt", {}),
    (
        D,
        "git -c remote.origin.pushurl=https://github.com/nrslib/takt push origin",
        "/w/mine",
        {},
    ),
    (D, "/usr/bin/git push upstream", "/w/takt", {}),
    (D, "command git push upstream", "/w/takt", {}),
    (D, r"\git push upstream", "/w/takt", {}),
    (D, "g\\it pu\\sh upstream", "/w/takt", {}),
    (D, "'git' 'push' \"upstream\"", "/w/takt", {}),
    (D, "git push $'\\x75pstream' main", "/w/takt", {}),
    (D, "git pu", "/w/alias", {}),  # git のエイリアス: pu = push upstream
    (D, "git sh", "/w/alias", {}),  # git のエイリアス: !git push upstream
    (D, "git -c alias.zz='push upstream' zz", "/w/takt", {}),
    (D, "git subtree push --prefix=docs upstream main", "/w/takt", {}),
    (D, "git send-pack https://github.com/nrslib/takt main", "/w/mine", {}),
    (D, "git-push upstream", "/w/takt", {}),
    (A, "git push origin main", "/w/takt", {}),
    (A, "git push", "/w/takt", {}),
    (A, "git push -u origin feat --force-with-lease", "/w/takt", {}),
    (A, "git push https://github.com/j5ik2o/takt.git main", "/w/clone", {}),
    (A, "git push", "/w/mine", {}),
    (A, "git push origin", "/w/corp", {}),
    (A, "git push ../backup main", "/w/clone", {}),
    (A, "git -C /w/mine push", "/w/clone", {}),
    (A, "git st", "/w/alias", {}),
    (A, "git fetch upstream", "/w/takt", {}),
    (A, "git pull upstream main", "/w/takt", {}),
    (A, "git log --oneline upstream/main", "/w/takt", {}),
    (A, "git remote -v", "/w/clone", {}),
    (
        A,
        "git merge upstream/main",
        "/w/takt",
        {},
    ),  # 手元のマージ（リポジトリには書かない）
    (A, "git commit -m 'push fix'", "/w/clone", {}),
    # --- 連結・入れ子 ------------------------------------------------------
    (D, "git status && git push upstream main", "/w/takt", {}),
    (D, "git status; git push upstream", "/w/takt", {}),
    (D, "git status || git push upstream", "/w/takt", {}),
    (D, "echo ok | git push upstream", "/w/takt", {}),
    (D, "(cd /w/takt && git push upstream)", "/w/mine", {}),
    (D, "{ git push upstream; }", "/w/takt", {}),
    (D, "bash -c 'git push upstream main'", "/w/takt", {}),
    (D, 'sh -c "gh pr merge 12 -R nrslib/takt"', "/w/mine", {}),
    (D, "zsh -lc 'cd /w/takt && git push upstream'", "/w/mine", {}),
    (D, "bash -c \"bash -c 'git push upstream'\"", "/w/takt", {}),
    (D, "env -i PATH=/usr/bin git push upstream", "/w/takt", {}),
    (D, "env -C /w/takt git push upstream", "/w/mine", {}),
    (D, "env -S 'git push upstream'", "/w/takt", {}),
    (D, "FOO=1 BAR=2 git push upstream", "/w/takt", {}),
    (D, "git status\ngit push upstream main\n", "/w/takt", {}),
    (D, "git status \\\n && git push upstream", "/w/takt", {}),
    (D, "echo $(git push upstream)", "/w/takt", {}),
    (D, "echo `gh pr merge 1 -R nrslib/takt`", "/w/mine", {}),
    (D, 'x="$(gh pr merge 1 -R nrslib/takt)"', "/w/mine", {}),
    (D, "eval 'git push upstream'", "/w/takt", {}),
    (D, "timeout 60 git push upstream", "/w/takt", {}),
    (D, "nohup git push upstream &", "/w/takt", {}),
    (D, "sudo -u me git push upstream", "/w/takt", {}),
    (D, "mise exec -- gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "if true; then git push upstream; fi", "/w/takt", {}),
    (D, "for i in 1; do git push upstream; done", "/w/takt", {}),
    (D, "bash <<'EOF'\ngit push upstream main\nEOF", "/w/takt", {}),
    (D, "bash <<< 'git push upstream'", "/w/takt", {}),
    (D, "echo 'git push upstream' | bash", "/w/takt", {}),
    (D, "find . -name x -exec git push upstream \\;", "/w/takt", {}),
    (D, "echo upstream | xargs git push", "/w/takt", {}),
    (D, "R=upstream; git push $R", "/w/takt", {}),
    (D, 'R=nrslib/takt; gh pr merge 1 -R "$R"', "/w/mine", {}),
    (D, "gh pr merge 1 -R ${REPO}", "/w/mine", {"REPO": "nrslib/takt"}),
    (A, "git status && git push origin main", "/w/takt", {}),
    (A, "(cd /w/clone && git status) && git push", "/w/mine", {}),
    (A, "bash -c 'gh pr view 1 -R nrslib/takt'", "/w/mine", {}),
    (A, "echo 'git push upstream'", "/w/takt", {}),
    (A, 'echo "gh pr merge 1 -R nrslib/takt" > notes.txt', "/w/mine", {}),
    (A, "grep -rn 'git push' docs/", "/w/takt", {}),
    (A, "cat <<'EOF' > memo.md\ngit push upstream\nEOF", "/w/takt", {}),
    (A, "ls -la && make test", "/w/mine", {}),
    # --- curl / 他の経路 ---------------------------------------------------
    (
        D,
        "curl -X PUT -H 'Authorization: token x' https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        'curl -sS -d \'{"ref":"refs/heads/x"}\' https://api.github.com/repos/nrslib/takt/git/refs',
        None,
        {},
    ),
    (
        D,
        "curl --request PATCH https://api.github.com/repos/nrslib/takt/git/refs/heads/main -d @b.json",
        None,
        {},
    ),
    (
        D,
        'curl -d \'{"query":"mutation{mergePullRequest(input:{pullRequestId:\\"x\\"}){clientMutationId}}"}\' https://api.github.com/graphql',
        None,
        {},
    ),
    (
        D,
        "curl -X POST https://github.com/nrslib/takt.git/git-receive-pack --data-binary @pack",
        None,
        {},
    ),
    (
        D,
        'python3 -c \'import subprocess; subprocess.run(["git","push","upstream"])\'',
        "/w/takt",
        {},
    ),
    (
        D,
        "node -e \"require('child_process').execSync('gh pr merge 1 -R nrslib/takt')\"",
        "/w/mine",
        {},
    ),
    (A, "curl -sS https://api.github.com/repos/nrslib/takt/pulls/1", None, {}),
    (A, "curl -X PUT https://api.github.com/repos/j5ik2o/takt/pulls/1/merge", None, {}),
    (A, "curl -sS https://example.com/upload -d x=1", None, {}),
    (A, "python3 -c 'print(1)'", "/w/mine", {}),
    (A, "python3 scripts/foo.py", "/w/mine", {}),
    # --- 解析できない・宛先を決められない ------------------------------------
    (D, "git push upstream 'main", "/w/takt", {}),  # 閉じていない引用符で push の気配
    (D, 'gh pr merge 1 -R "nrslib/takt', "/w/mine", {}),
    (A, "echo 'unterminated", "/w/mine", {}),  # 解析できないが push/merge でない
    (D, "git push $REMOTE main", "/w/takt", {}),  # 変数が決まらない
    (D, 'git push "$(git remote | head -1)"', "/w/takt", {}),
    (D, "$GIT push origin", "/w/mine", {}),  # 実行ファイルが決まらない
    (D, "gh pr merge 1 -R $R", "/w/mine", {}),
    (D, "gh pr merge 1", "/w/notrepo", {}),  # git の設定を読めない
    (D, "gh pr merge 1", None, {}),  # 作業ディレクトリが分からない
    (D, "git push", "/w/notrepo", {}),
    (D, "git push", "/w/nodefault", {}),  # 既定の push 先が決まらない
    (D, "git push nosuchremote main", "/w/takt", {}),
    (D, "git -C $DIR push", "/w/mine", {}),
    (D, "cd $DIR && git push", "/w/mine", {}),
    (D, "git $SUB upstream", "/w/takt", {}),
    (D, "gh $CMD merge 1", "/w/mine", {}),
    (D, "git --git-dir=/w/takt-unresolved/.git push", "/w/mine", {}),
    (A, "$EDITOR notes.txt", "/w/mine", {}),
    (A, "cd $DIR && ls", "/w/mine", {}),
    (A, "git status", "/w/notrepo", {}),
    (A, "", "/w/mine", {}),
    # --- 独立レビューで見つかったすり抜け ------------------------------------
    (D, "gh pr merge feature/foo", "/w/clone", {}),  # ブランチ名の / は宛先ではない
    (D, "gh pr update-branch fix/x", "/w/clone", {}),
    (
        D,
        "git remote set-url origin https://github.com/nrslib/takt && git push origin",
        "/w/mine",
        {},
    ),
    (D, "git config remote.pushDefault upstream && git push", "/w/takt-unresolved", {}),
    (D, "gh repo set-default nrslib/takt && gh pr merge 1", "/w/takt", {}),
    (
        D,
        "git config alias.pp 'push https://github.com/nrslib/takt' && git pp",
        "/w/mine",
        {},
    ),
    (D, "git -c remote.pushDefault=upstream push", "/w/takt-unresolved", {}),
    (D, "git -c branch.main.pushRemote=upstream push", "/w/takt-unresolved", {}),
    (D, 'git -c "remote.origin.pushurl=$U" push origin', "/w/mine", {}),
    (
        D,
        "git -c url.https://github.com/nrslib/.insteadOf=https://github.com/j5ik2o/ push https://github.com/j5ik2o/takt",
        "/w/mine",
        {},
    ),
    (
        D,
        "PU=https://github.com/nrslib/takt git --config-env=remote.origin.pushurl=PU push origin",
        "/w/mine",
        {},
    ),
    (
        D,
        "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.pushurl GIT_CONFIG_VALUE_0=x git push origin",
        "/w/mine",
        {},
    ),
    (D, "git push https://github.com/j5ik2o/../nrslib/takt", "/w/mine", {}),
    (D, "git push https://github.com/%6Erslib/takt", "/w/mine", {}),
    (D, "cd /w/mine | true; git push origin", "/w/clone", {}),
    (D, "cd /w/mine &\ngit push origin", "/w/clone", {}),
    (D, "gh -R nrslib/takt pr merge 1", "/w/mine", {}),
    (D, "gh --repo nrslib/takt pr merge 1", "/w/mine", {}),
    (D, "gh -R nrslib/takt release create v1", "/w/mine", {}),
    (D, "curl -sXPUT https://api.github.com/repos/nrslib/takt/pulls/1/merge", None, {}),
    (
        D,
        "curl -sX PUT https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (D, "curl -X PUT https://API.GITHUB.COM/repos/nrslib/takt/pulls/1/merge", None, {}),
    (D, "curl -X PUT HTTPS://api.github.com/repos/nrslib/takt/pulls/1/merge", None, {}),
    (
        D,
        "curl -X PUT https://x:tok@api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        "curl -X PUT https://api.github.com/repos/j5ik2o/x/../../nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        "curl -X POST -T a.zip 'https://uploads.github.com/repos/nrslib/takt/releases/1/assets?name=a.zip'",
        None,
        {},
    ),
    (D, "env --chdir=/w/clone git push origin", "/w/mine", {}),
    (D, "function f { git push origin; }; f", "/w/clone", {}),
    (D, "coproc git push origin", "/w/clone", {}),
    (D, "trap 'git push origin' EXIT", "/w/clone", {}),
    (D, "bash -c -- 'git push origin'", "/w/clone", {}),
    (D, "$(echo git push origin)", "/w/clone", {}),
    (D, "X=$(echo git push origin); $X", "/w/clone", {}),
    (D, "cat <<EOF\n$(git push origin)\nEOF", "/w/clone", {}),
    (D, "echo $(( $(git push origin) ))", "/w/clone", {}),
    (D, "echo ${u:-$(git push origin)}", "/w/clone", {}),
    (D, "git push https://github.com/nrsli{b..b}/takt", "/w/mine", {}),
    (D, "gh pr merge 1 -R nrsli{b..b}/takt", "/w/mine", {}),
    (D, "gh pr merge 1 -R{x,nrslib}/takt", "/w/mine", {}),
    (D, "R=nrs; R+=lib/takt; gh pr merge 1 -R $R", "/w/mine", {}),
    (D, "export GH_REPO=nrs; GH_REPO+=lib/takt; gh pr merge 1", "/w/mine", {}),
    (D, "export GIT_DIR=/w/clone/.git; git push origin", "/w/mine", {}),
    (D, "hub api -X PUT repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    (D, "gh api -X PUT repositories/123456/pulls/1/merge", "/w/mine", {}),
    (D, "gh api -X PUT repos/nrslib/takt/pulls/1/%6Derge", "/w/mine", {}),
    (D, "uv run gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "nix develop -c gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "mise exec -c 'gh pr merge 1 -R nrslib/takt'", "/w/mine", {}),
    (D, "awk 'BEGIN{system(\"gh pr merge 1 -R nrslib/takt\")}'", "/w/mine", {}),
    (D, "parallel gh pr merge ::: 1 2 -R nrslib/takt", "/w/mine", {}),
    # --- orca の本文の引数（2026-11-25 の誤った拒否の 2 件目） ------------------
    (
        A,
        'cd /w/mine && "${ORCA_CLI_COMMAND:-orca}" bot item comment 264 --text "マージと push は止めた。nrslib 宛ての git push upstream と gh pr merge -R nrslib/takt は拒否。dotfiles にブランチができた" 2>&1 | tail -1',
        "/w/home",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" bot item comment 264 --text "push merge マージ nrslib git push upstream gh pr merge -R nrslib/takt"',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca bot item comment 264 --text "push merge マージ nrslib git push upstream gh pr merge -R nrslib/takt" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        'cd /w/mine && orca orchestration send --from s --type status --subject "merge と push の件" --body "git push upstream と gh pr merge -R nrslib/takt は使わない" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" orchestration send --to x --subject "push の件" --body "nrslib へ git push しない"',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca orchestration reply --id m1 --body "gh pr merge -R nrslib/takt はマージしない。push もしない"',
        "/w/mine",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" orchestration reply --id m1 --body "git push upstream main は拒否された" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca bot reply --text "マージと push は上流のメンテナが行う。nrslib/takt の gh pr merge は使わない"',
        "/w/mine",
        {},
    ),
    (
        A,
        'cd /w/mine && "${ORCA_CLI_COMMAND:-orca}" bot reply --text "git push upstream / gh pr merge -R nrslib/takt" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (A, '"$ORCA_CLI_COMMAND" bot item comment 1 --text "push と merge"', "/w/mine", {}),
    (
        D,
        '"${GIT:-git}" push https://github.com/nrslib/takt main',
        "/w/mine",
        {},
    ),  # 名前は変数でも、語の位置が push
    (D, "$GH pr merge 1 -R nrslib/takt", "/w/mine", {}),
    # --- 文やデータに語句があるだけのものは通す（2026-11-25 の誤った拒否） -----
    (
        A,
        "python3 - <<'EOF'\nfrom pathlib import Path\np = Path('MEMORY.md')\np.write_text(p.read_text() + '- 事故: git push が走った。nrslib 宛てのマージと push を実行前に拒否する（gh pr merge は使わない）\\n')\nEOF",
        "/w/mine",
        {},
    ),
    (
        A,
        "python3 -c \"open('memo.md','a').write('nrslib/takt へ git push しない。gh pr merge -R nrslib/takt も使わない')\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "node -e \"require('fs').appendFileSync('m.md', 'git push upstream と gh pr merge は nrslib 宛てに使わない')\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "orca orchestration send --to x --subject 'merge の件' --body '… gh pr merge は使わない。nrslib/takt へ git push しない …'",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh issue comment 5 -R j5ik2o/takt --body 'nrslib/takt へ git push しない'",
        "/w/mine",
        {},
    ),
    (A, "git commit -m 'docs: git push upstream を禁止（nrslib）'", "/w/takt", {}),
    (
        A,
        "cat > notes.md <<'EOF'\ngh pr merge -R nrslib/takt 12\ngit push upstream main\nEOF",
        "/w/takt",
        {},
    ),
    (A, "tee notes.md <<'EOF'\ngh pr merge -R nrslib/takt 12\nEOF", "/w/takt", {}),
    (A, "echo 'gh pr merge -R nrslib/takt 12' >> notes.md", "/w/mine", {}),
    (
        A,
        "printf '%s\\n' 'git push https://github.com/nrslib/takt main' > notes.md",
        "/w/mine",
        {},
    ),
    (A, "awk '{print \"git push nrslib\"}' notes.md", "/w/mine", {}),
    (A, "sed -i 's/gh pr merge/gh pr view/' notes.md", "/w/mine", {}),
    (
        D,
        "python3 -c \"import subprocess; subprocess.run(['gh','pr','merge','1','-R','nrslib/takt'])\"",
        "/w/mine",
        {},
    ),
    (
        D,
        "node -e \"require('child_process').execSync('git push https://github.com/nrslib/takt.git main')\"",
        "/w/mine",
        {},
    ),
    (
        D,
        "python3 - <<'EOF'\nimport os\nos.system('gh pr merge 1 -R nrslib/takt')\nEOF",
        "/w/mine",
        {},
    ),
    (
        D,
        "python3 -c \"import requests; requests.put('https://api.github.com/repos/nrslib/takt/pulls/1/merge')\"",
        None,
        {},
    ),
    (D, "ruby -e 'system(\"git push upstream\")'", "/w/takt", {}),
    (
        D,
        "bash -c 'gh pr merge 1 -R nrslib/takt'",
        "/w/mine",
        {},
    ),  # 文字列を実行する形は中を見る
    (D, 'eval "gh pr merge 1 -R nrslib/takt"', "/w/mine", {}),
    (D, "echo 1 | xargs gh pr merge -R nrslib/takt", "/w/mine", {}),
    (
        D,
        "awk 'BEGIN{system(\"git push https://github.com/nrslib/takt\")}'",
        "/w/mine",
        {},
    ),
    (D, "cd /w/mine; cd -; git push origin", "/w/clone", {}),
    # 二重引用符の中のバッククォートは、シェルが先に実行する
    (
        D,
        "node -e \"require('fs').writeFileSync('d.md', '`git push upstream` は使わない')\"",
        "/w/takt",
        {},
    ),
    # Markdown のバッククォートを含む文を python で書く（2026-11-25 の誤った拒否の 3 件目）
    (
        A,
        "python3 - <<'PYEOF'\nopen('d.md','a').write('- `git push \"$REMOTE\"` と `gh pr merge -R nrslib/takt` は止める\\n')\nPYEOF",
        "/w/mine",
        {},
    ),
    (
        A,
        # 単一引用符の中なので、シェルはバッククォートを実行しない
        'node -e \'require("fs").writeFileSync("d.md", "`git push upstream` は使わない")\'',
        "/w/mine",
        {},
    ),
    (D, "ruby -e 'puts `git push https://github.com/nrslib/takt`'", "/w/mine", {}),
    (D, "perl -e 'print `gh pr merge 1 -R nrslib/takt`'", "/w/mine", {}),
    # ヒアドキュメントの本文に区切りの行が入っていると、そこで閉じて残りの行がコマンドになる
    # （2026-11-25 の独立レビューで、試験の入力をこの形でシェルに渡して git push が走った）
    (
        D,
        "cat > cases.txt <<'EOF'\nfirst line\nEOF\ngit push origin\nEOF",
        "/w/clone",
        {},
    ),
    (
        D,
        "cat > cases.txt <<'EOF'\n(D, \"x\")\nEOF\n$(git push origin)\n(( 1 +\nEOF",
        "/w/clone",
        {},
    ),
    (
        A,
        "cat > cases.txt <<'EOF'\ngit push origin\n$(git push origin)\nEOF",
        "/w/clone",
        {},
    ),
    (
        A,
        "cat > cases.txt <<'END'\nEOF\ngit push origin\nEND\necho done",
        "/w/clone",
        {},
    ),
    (D, "diff <(git push origin) x", "/w/clone", {}),  # プロセス置換の中も実行される
    (A, "diff <(head -2 a.txt) b.txt && echo merge-ok", "/w/clone", {}),
    # --- 独立レビューで見つかった誤った拒否（通す） --------------------------
    (
        A,
        "git commit -m \"$(cat <<'EOF'\nfix(x): don't drop it\nEOF\n)\" && git push origin HEAD",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh pr create --body \"$(cat <<'EOF'\nIt's fine\nEOF\n)\" && gh pr merge --auto 3",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh pr view 5 -R nrslib/takt --json mergeable,title | python3 -c 'import json,sys; print(1)'",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh api repos/nrslib/takt/contents/README.md | python3 -c 'print(1)'",
        "/w/mine",
        {},
    ),
    (A, "gh release view -R nrslib/takt v1 | python3 -c 'print(1)'", "/w/mine", {}),
    (A, "gh pr merge feature/foo", "/w/mine", {}),
    (A, "git config --get remote.origin.url && git push origin", "/w/mine", {}),
    # --- PR #229 のレビューの指摘（入力は指摘のまま） ------------------------
    # B-1: gh repo rename の引数は新しい名前で、宛先は -R か既定のリポジトリ
    (A, "gh repo rename nrslib-fork", "/w/mine", {}),
    (A, "gh repo rename takt2 -R j5ik2o/takt", "/w/clone", {}),
    (D, "gh repo rename x -R nrslib/takt", "/w/mine", {}),
    (D, "gh repo rename x", "/w/clone", {}),
    # B-2: HEAD は読み取り
    (A, "gh api --method HEAD repos/nrslib/takt/contents/README.md", "/w/mine", {}),
    (A, "gh api -X HEAD repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    # A-1: eval は同じシェルの cd を引き継ぐ。bash -c は引き継がない
    (D, "eval 'cd /w/clone'; git push origin", "/w/mine", {}),
    (D, "eval cd /w/clone && git push origin", "/w/mine", {}),
    (A, "bash -c 'cd /w/clone'; git push origin", "/w/mine", {}),
    # A-2: 引用されていない変数の展開は、コマンドの位置で単語に分かれる
    (D, "X='git push origin'; $X", "/w/clone", {}),
    (D, "P='gh pr merge'; $P 1 -R nrslib/takt", "/w/mine", {}),
    (A, "X='echo hi'; $X", "/w/clone", {}),
    (A, 'X="git push origin"; echo "$X"', "/w/clone", {}),
    (A, "X='git push origin'; $X", "/w/mine", {}),
    # A-3: env -u と env -i で消した環境変数は、判定でも消す
    (D, "env -u GH_REPO gh pr merge 1", "/w/clone", {"GH_REPO": "j5ik2o/x"}),
    (D, "env -i gh pr merge 1", "/w/clone", {"GH_REPO": "j5ik2o/x"}),
    (D, "env -u GIT_DIR git push", "/w/clone", {"GIT_DIR": "/w/mine/.git"}),
    (A, "git push", "/w/clone", {"GIT_DIR": "/w/mine/.git"}),
    # A-4: curl の -O は値を取らない
    (
        D,
        "curl -X PUT -O https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    # A-5: {owner} と {repo} は片方ずつ置き換える
    (D, "gh api -X PUT repos/nrslib/{repo}/pulls/1/merge", "/w/mine", {}),
    (A, "gh api -X PUT repos/j5ik2o/{repo}/pulls/1/merge", "/w/clone", {}),
    # A-6: gh は :owner と :repo も置き換える（gh 2.105.0 の正規表現で確認）
    (D, "gh api -X PUT repos/:owner/:repo/pulls/1/merge", "/w/clone", {}),
    (D, "gh api -X PUT repos/nrslib/:repo/pulls/1/merge", "/w/mine", {}),
    (A, "gh api -X PUT repos/j5ik2o/:repo/pulls/1/merge", "/w/clone", {}),
    # A-7: -R と --repo が両方あれば、どれか 1 つでも禁止の宛先なら止める
    (D, "gh pr merge 1 --repo nrslib/takt -R j5ik2o/takt", "/w/mine", {}),
    (D, "gh pr merge 1 -R nrslib/takt -R j5ik2o/takt", "/w/mine", {}),
    # A-8: curl --next は転送ごとにメソッドと本文を分ける
    (
        D,
        "curl -X GET https://api.github.com/repos/nrslib/takt --next -d x https://api.github.com/repos/nrslib/takt/git/refs",
        None,
        {},
    ),
    (
        A,
        "curl -X PUT https://api.github.com/repos/j5ik2o/x/pulls/1/merge --next https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    # A-9: 相対の --git-dir と GIT_DIR は、-C の後の場所で解決する
    (D, "git --git-dir=.git -C /w/clone push origin", "/w/mine", {}),
    (D, "GIT_DIR=.git git -C /w/clone push origin", "/w/mine", {}),
    (D, "git -C /w/clone --git-dir=.git push origin", "/w/mine", {}),
    # A-10: busybox sh -c の中も見る
    (D, "busybox sh -c 'git push origin'", "/w/clone", {}),
    (A, "busybox sh -c 'git push origin'", "/w/mine", {}),
    # A-11: ヒアドキュメントが 2 つあると、シェルが読むのは最後
    (D, "bash <<'A' <<'B'\nls\nA\ngit push origin\nB", "/w/clone", {}),
    (A, "bash <<'A' <<'B'\ngit push origin\nA\nls\nB", "/w/clone", {}),
    # F-1、F-2: 2026-11-25 11:04 の誤った拒否（ほかのボットのレビューへの返信と解決）
    (
        A,
        "for id in 1 2; do gh api -X POST repos/j5ik2o/takt/pulls/1025/comments/$id/replies -F body=@$d/$id --jq .id; done",
        "/w/mine",
        {},
    ),
    (
        D,
        "for n in 1; do gh api -X PUT repos/nrslib/takt/pulls/$n/merge; done",
        "/w/mine",
        {},
    ),
    (D, "gh api -X PUT repos/$O/takt/pulls/1/merge", "/w/mine", {}),
    (
        A,
        'q=$(python3 -c "print(\'mutation{r0: resolveReviewThread(input:{threadId:\\"T\\"}){thread{isResolved}}}\')"); gh api graphql -f query="$q"',
        "/w/mine",
        {},
    ),
    (
        A,
        "python3 -c \"open('/tmp/r.graphql','w').write('mutation{resolveReviewThread(input:{threadId:1}){thread{isResolved}}}')\"; gh api graphql -F query=@/tmp/r.graphql --jq '[.data[]] | length'",
        "/w/mine",
        {},
    ),
    (
        D,
        'q=$(python3 -c "print(\'mutation{mergePullRequest(input:{pullRequestId:1}){clientMutationId}}\')"); gh api graphql -f query="$q"',
        "/w/mine",
        {},
    ),
    (
        D,
        "python3 -c \"open('/tmp/m.graphql','w').write('mutation{enablePullRequestAutoMerge(input:{pullRequestId:1}){clientMutationId}}')\"; gh api graphql -F query=@/tmp/m.graphql",
        "/w/mine",
        {},
    ),
    # D-3: 拒否の例と同じ起動の形で、宛先だけが禁止でないもの
    (
        A,
        "python3 -c \"import subprocess; subprocess.run(['gh','pr','merge','1','-R','j5ik2o/takt'])\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "node -e \"require('child_process').execSync('git push https://github.com/j5ik2o/takt.git main')\"",
        "/w/mine",
        {},
    ),
]


class DecideTable(unittest.TestCase):
    def test_table(self):
        failures = []
        for expected, command, cwd, extra in CASES:
            verdict = ug.decide(
                command, cwd, {**ENV, **extra}, ("nrslib",), Repos(REPOS)
            )
            got = A if verdict.allowed else D
            if got != expected:
                failures.append(
                    f"{expected} を期待して {got}: {command!r} (cwd={cwd})\n    {verdict.reason}"
                )
            if not verdict.allowed:
                lines = verdict.reason.splitlines()
                if not (1 <= len(lines) <= 3) or "副元帥" not in verdict.reason:
                    failures.append(
                        f"拒否のメッセージの形が違う: {command!r}: {verdict.reason!r}"
                    )
        self.assertEqual(failures, [], "\n".join(failures))


class Blocked(unittest.TestCase):
    def test_owner_and_repo_entries_ignore_case(self):
        self.assertEqual(ug.blocked_entry("nrslib/takt", ("NRSLIB",)), "NRSLIB")
        self.assertEqual(
            ug.blocked_entry("j5ik2o/ci-gate-sandbox", ("j5ik2o/CI-Gate-Sandbox",)),
            "j5ik2o/CI-Gate-Sandbox",
        )
        self.assertIsNone(ug.blocked_entry("j5ik2o/takt", ("j5ik2o/ci-gate-sandbox",)))

    def test_repo_entry_blocks_only_that_repo(self):
        repos = Repos(REPOS)
        blocked = ("nrslib", "j5ik2o/ci-gate-sandbox")
        self.assertFalse(
            ug.decide(
                "gh pr merge 1 -R j5ik2o/ci-gate-sandbox",
                "/w/mine",
                ENV,
                blocked,
                repos,
            ).allowed
        )
        self.assertTrue(
            ug.decide(
                "gh pr merge 1 -R j5ik2o/takt", "/w/mine", ENV, blocked, repos
            ).allowed
        )

    def test_opaque_code_matches_whole_repo_entry(self):
        blocked = ("nrslib", "j5ik2o/ci-gate-sandbox")
        code = "python3 -c 'print(\"/Users/j5ik2o/x: push の判定\")'"
        self.assertTrue(ug.decide(code, "/w/mine", ENV, blocked, Repos(REPOS)).allowed)
        code = 'python3 -c \'subprocess.run("j5ik2o/ci-gate-sandbox", "push")\''
        self.assertFalse(ug.decide(code, "/w/mine", ENV, blocked, Repos(REPOS)).allowed)

    def test_overrides_only_add(self, tmp_home="/nonexistent-home"):
        self.assertEqual(ug.load_blocked({}, tmp_home), ("nrslib",))
        added = ug.load_blocked(
            {ug.EXTRA_BLOCKED_ENV: "j5ik2o/ci-gate-sandbox, foo"}, tmp_home
        )
        self.assertEqual(added, ("nrslib", "j5ik2o/ci-gate-sandbox", "foo"))
        self.assertIn("nrslib", ug.load_blocked({ug.EXTRA_BLOCKED_ENV: ""}, tmp_home))
        self.assertIn(
            "nrslib",
            ug.load_blocked({ug.EXTRA_BLOCKED_ENV: "-nrslib !nrslib"}, tmp_home),
        )


class Hook(unittest.TestCase):
    def payload(self, command, cwd="/nonexistent"):
        return json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd}
        )

    def test_does_nothing_outside_orca_sessions(self):
        code, msg = ug.hook_main(
            self.payload("git push https://github.com/nrslib/takt main"), {"HOME": "/x"}
        )
        self.assertEqual((code, msg), (0, ""))

    def test_blocks_in_orca_sessions(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        code, msg = ug.hook_main(
            self.payload("git push https://github.com/nrslib/takt main"), env
        )
        self.assertEqual(code, 2)
        self.assertIn("nrslib/takt", msg)

    def test_monitor_commands_are_checked(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        payload = json.dumps(
            {
                "tool_name": "Monitor",
                "tool_input": {"command": "git push git@github.com:nrslib/t"},
            }
        )
        self.assertEqual(ug.hook_main(payload, env)[0], 2)

    def test_other_tools_pass(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        payload = json.dumps({"tool_name": "Read", "tool_input": {"file_path": "/x"}})
        self.assertEqual(ug.hook_main(payload, env), (0, ""))

    def run_wrapper(self, target: str, env: dict[str, str]):
        import subprocess

        cmd = ug.HOOK_COMMAND.replace(ug.HOOK_BIN, target)
        return subprocess.run(
            ["sh", "-c", cmd],
            input=self.payload("ls"),
            capture_output=True,
            text=True,
            env={"PATH": "/usr/bin:/bin", **env},
            check=False,
        )

    def test_wrapper_warns_without_blocking_when_binary_is_missing_or_broken(self):
        import tempfile

        tmp = tempfile.mkdtemp()
        broken = os.path.join(tmp, "broken")
        with open(broken, "w") as f:
            f.write("#!/bin/sh\nexit 1\n")
        os.chmod(broken, 0o755)
        dangling = os.path.join(tmp, "dangling")
        os.symlink(os.path.join(tmp, "gone"), dangling)
        # 無いときと、0・2 以外で終わったとき（終了コードつき）は、別の文にする
        for target, expected in (
            (os.path.join(tmp, "missing"), "実行ファイルが無いため"),
            (dangling, "実行ファイルが無いため"),
            (broken, "判定が終了コード 1 で失敗したため"),
        ):
            r = self.run_wrapper(target, {"ORCA_AGENT_SESSION_ID": "s"})
            self.assertEqual(r.returncode, 0, target)
            out = json.loads(r.stdout)
            context = out["hookSpecificOutput"]["additionalContext"]
            self.assertIn(expected, context)
            self.assertIn(expected, out["systemMessage"])
            self.assertIn("判定をしていません", context)
            owner = self.run_wrapper(target, {})
            self.assertEqual((owner.returncode, owner.stdout), (0, ""))

    def test_wrapper_passes_through_the_verdict(self):
        import tempfile

        tmp = tempfile.mkdtemp()
        deny = os.path.join(tmp, "deny")
        with open(deny, "w") as f:
            f.write("#!/bin/sh\necho stopped >&2\nexit 2\n")
        os.chmod(deny, 0o755)
        r = self.run_wrapper(deny, {"ORCA_AGENT_SESSION_ID": "s"})
        self.assertEqual((r.returncode, r.stderr.strip()), (2, "stopped"))

    def test_internal_error_fails_closed_for_push(self):
        self.assertFalse(ug._fallback("git push upstream").allowed)
        self.assertTrue(ug._fallback("ls -la").allowed)

    def test_graphql_query_file_is_read(self):
        # F-2: 読めるクエリのファイルに、マージの mutation があれば止める
        files = {
            "/w/mine/merge.graphql": "mutation{mergePullRequest(input:{pullRequestId:1}){clientMutationId}}",
            "/w/mine/resolve.graphql": "mutation{resolveReviewThread(input:{threadId:1}){thread{isResolved}}}",
        }
        repos = Repos(REPOS)
        for command, expected in (
            ("gh api graphql -F query=@merge.graphql", False),
            ("gh api graphql --input merge.graphql", False),
            ("gh api graphql -F query=@resolve.graphql", True),
            ("gh api graphql -F query=@/w/mine/resolve.graphql", True),
        ):
            v = ug.decide(command, "/w/mine", ENV, ("nrslib",), repos, files)
            self.assertEqual(v.allowed, expected, command)

    def test_hook_command_matches_the_shellchecked_script(self):
        # D-1: 登録するシェルの行は scripts/upstream-guard-hook.sh と同じ（そちらに shellcheck が掛かる）
        path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..",
            "scripts",
            "upstream-guard-hook.sh",
        )
        with open(path, encoding="utf-8") as f:
            lines = [
                line.rstrip("\n")
                for line in f
                if line.strip() and not line.startswith("#")
            ]
        self.assertEqual(lines, [ug.HOOK_COMMAND])

    def test_failing_extra_blocked_list_still_uses_the_default_list(self):
        # A-13 と D-4: 追加の一覧を読めなくても、既定の一覧で decide() まで通す
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        original = ug.load_blocked

        def broken(*_args):
            raise UnicodeDecodeError("utf-8", b"\xff", 0, 1, "壊れた一覧")

        ug.load_blocked = broken
        try:
            push = self.payload("git push https://github.com/nrslib/takt main")
            self.assertEqual(ug.hook_main(push, env)[0], 2)
            # 推測だけの _fallback では通ってしまい、decide() なら止まる形
            merge = self.payload("G=gh; $G pr merge 1 -R nrslib/takt")
            self.assertTrue(ug._fallback("G=gh; $G pr merge 1 -R nrslib/takt").allowed)
            self.assertEqual(ug.hook_main(merge, env)[0], 2)
            read = self.payload("gh pr view 1 -R nrslib/takt")
            self.assertEqual(ug.hook_main(read, env), (0, ""))
            note = self.payload(
                "orca bot reply --text 'git push と gh pr merge は使わない'"
            )
            self.assertEqual(ug.hook_main(note, env), (0, ""))
        finally:
            ug.load_blocked = original


class RealGitConfig(unittest.TestCase):
    """D-2: 一時リポジトリの実際の git の設定を読む。git は手元の設定だけを読み、ネットワークに出ない。"""

    def setUp(self):
        import tempfile

        self.saved = {
            k: os.environ.get(k) for k in ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM")
        }
        os.environ["GIT_CONFIG_GLOBAL"] = os.devnull
        os.environ["GIT_CONFIG_NOSYSTEM"] = "1"
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def repo(self, *configs: tuple[str, ...]) -> str:
        import subprocess
        import tempfile

        path = tempfile.mkdtemp(dir=self.dir)
        subprocess.run(["git", "init", "-q", "-b", "main", path], check=True)
        for args in configs:
            subprocess.run(["git", "-C", path, *args], check=True)
        return path

    def verdict(self, command: str, cwd: str) -> str:
        env = {"HOME": self.dir, "PATH": os.environ.get("PATH", "")}
        return "allow" if ug.check(command, cwd, env).allowed else "deny"

    def test_push_targets_come_from_the_real_config(self):
        mine = self.repo(("remote", "add", "origin", "https://github.com/j5ik2o/takt"))
        self.assertEqual(self.verdict("git push", mine), "allow")
        self.assertEqual(self.verdict("git push origin main", mine), "allow")
        pushurl = self.repo(
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "set-url", "--push", "origin", "git@github.com:nrslib/takt.git"),
        )
        self.assertEqual(self.verdict("git push origin", pushurl), "deny")
        rewritten = self.repo(
            ("config", "url.https://github.com/nrslib/.insteadOf", "up:"),
            ("remote", "add", "origin", "up:takt"),
        )
        self.assertEqual(self.verdict("git push origin", rewritten), "deny")
        push_remote = self.repo(
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "add", "up", "https://github.com/nrslib/takt"),
            ("config", "branch.main.pushRemote", "up"),
        )
        self.assertEqual(self.verdict("git push", push_remote), "deny")
        self.assertEqual(self.verdict("git push origin", push_remote), "allow")

    def test_gh_default_repo_follows_set_default(self):
        both = (
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "add", "upstream", "https://github.com/nrslib/takt.git"),
        )
        unresolved = self.repo(*both)
        self.assertEqual(self.verdict("gh pr merge 3", unresolved), "deny")
        resolved = self.repo(*both, ("config", "remote.origin.gh-resolved", "base"))
        self.assertEqual(self.verdict("gh pr merge 3", resolved), "allow")

    def test_unreadable_push_urls_make_the_target_unknown(self):
        # A-12: push の URL を読めなかった remote は、空の一覧ではなく「決まらない」
        mine = self.repo(("remote", "add", "origin", "https://github.com/j5ik2o/takt"))
        original = ug._git

        def flaky(location, *args):
            if args[:3] == ("remote", "get-url", "--push"):
                return None
            return original(location, *args)

        ug._git = flaky
        try:
            info = ug.read_repo_info(mine)
            v = ug.decide("git push origin", mine, {}, ("nrslib",), {mine: info})
            self.assertFalse(v.allowed)
        finally:
            ug._git = original


class CheckCommand(unittest.TestCase):
    def test_check_entry_returns_verdict_without_running(self):
        import contextlib
        import io

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ug.main(
                [
                    "upstream-guard",
                    "check",
                    "--cwd",
                    "/nonexistent",
                    "--",
                    "gh pr merge 1 -R nrslib/takt",
                ]
            )
        self.assertEqual(code, 2)
        self.assertTrue(out.getvalue().startswith("deny"))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(
                ug.main(
                    ["upstream-guard", "check", "--", "gh pr view 1 -R nrslib/takt"]
                ),
                0,
            )


class Install(unittest.TestCase):
    ORCA_GROUP: ClassVar[dict] = {
        "hooks": [
            {
                "type": "command",
                "command": ": orca-agent-hook-form=2; true",
                "timeout": 10,
            }
        ]
    }

    def setUp(self):
        import tempfile

        self.home = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.home, ".claude"))
        os.makedirs(os.path.join(self.home, ".codex"))
        self.files = {
            ".claude/settings.json": json.dumps(
                {"model": "x", "hooks": {"PreToolUse": [self.ORCA_GROUP]}}, indent=2
            )
            + "\n",
            ".codex/hooks.json": json.dumps(
                {"hooks": {"PreToolUse": [self.ORCA_GROUP]}}, indent=2
            )
            + "\n",
            ".codex/config.toml": 'model = "m"\n\n[hooks.state."x:pre_tool_use:0:0"]\nenabled = true\n',
        }
        for rel, text in self.files.items():
            with open(os.path.join(self.home, rel), "w") as f:
                f.write(text)

    def read(self, rel):
        with open(os.path.join(self.home, rel)) as f:
            return f.read()

    def test_install_is_idempotent_and_uninstall_restores(self):
        ug.apply_install(self.home, True, "t1")
        settings = json.loads(self.read(".claude/settings.json"))
        self.assertEqual(settings["hooks"]["PreToolUse"][0], self.ORCA_GROUP)
        self.assertEqual(
            settings["hooks"]["PreToolUse"][1]["hooks"][0]["command"], ug.HOOK_COMMAND
        )
        hooks_path = os.path.realpath(os.path.join(self.home, ".codex/hooks.json"))
        config = self.read(".codex/config.toml")
        self.assertIn(f'[hooks.state."{hooks_path}:pre_tool_use:1:0"]', config)
        self.assertIn(ug.codex_trusted_hash(ug._hook_group(ug.CODEX_MATCHER)), config)
        first = {rel: self.read(rel) for rel in self.files}
        ug.apply_install(self.home, True, "t2")
        self.assertEqual({rel: self.read(rel) for rel in self.files}, first)
        self.assertFalse(
            any("t2" in n for n in os.listdir(os.path.join(self.home, ".codex")))
        )
        ug.apply_install(self.home, False, "t3")
        self.assertEqual({rel: self.read(rel) for rel in self.files}, self.files)
        self.assertTrue(
            os.path.exists(
                os.path.join(self.home, ".claude/settings.json.bak-upstream-guard-t1")
            )
        )

    def test_install_creates_missing_settings_and_reports_missing_agents(self):
        # C-1: 設定ファイルが無ければ作り、エージェントの置き場が無ければ登録できなかったと返す
        import shutil
        import tempfile

        os.remove(os.path.join(self.home, ".claude/settings.json"))
        result = ug.apply_install(self.home, True, "t1")
        settings = json.loads(self.read(".claude/settings.json"))
        self.assertEqual(
            settings["hooks"]["PreToolUse"][0]["hooks"][0]["command"], ug.HOOK_COMMAND
        )
        self.assertEqual(result.skipped, [])
        bare = tempfile.mkdtemp()
        os.makedirs(os.path.join(bare, ".claude"))
        result = ug.apply_install(bare, True, "t1")
        self.assertEqual(len(result.skipped), 1)
        self.assertIn("Codex", result.skipped[0])
        shutil.rmtree(bare)

    def test_uninstall_keeps_other_hooks_in_the_same_group(self):
        # C-2: 同じグループにあるほかのフックは消さない
        other = {"type": "command", "command": "other-hook", "timeout": 5}
        group = {
            "matcher": "Bash",
            "hooks": [other, ug._hook_group("Bash")["hooks"][0]],
        }
        path = os.path.join(self.home, ".claude/settings.json")
        with open(path, "w") as f:
            json.dump({"hooks": {"PreToolUse": [group]}}, f)
        ug.apply_install(self.home, False, "t1")
        groups = json.loads(self.read(".claude/settings.json"))["hooks"]["PreToolUse"]
        self.assertEqual(groups, [{"matcher": "Bash", "hooks": [other]}])

    def test_trust_key_escapes_the_path(self):
        # C-3: パスに " や \\ があっても config.toml が読める
        import tempfile
        import tomllib

        home = os.path.join(tempfile.mkdtemp(), 'we"ird\\home')
        os.makedirs(os.path.join(home, ".codex"))
        os.makedirs(os.path.join(home, ".claude"))
        ug.apply_install(home, True, "t1")
        with open(os.path.join(home, ".codex/config.toml"), "rb") as f:
            state = tomllib.load(f)["hooks"]["state"]
        real = os.path.join(
            os.path.realpath(os.path.join(home, ".codex")), "hooks.json"
        )
        self.assertIn(f"{real}:pre_tool_use:0:0", state)

    def test_codex_files_are_written_together_or_not_at_all(self):
        # C-4: config.toml を書けなければ、hooks.json も元のまま
        config = os.path.join(self.home, ".codex/config.toml")
        os.chmod(config, 0o444)
        try:
            with self.assertRaises(OSError):
                ug.apply_install(self.home, True, "t1")
        finally:
            os.chmod(config, 0o644)
        self.assertEqual(
            self.read(".codex/hooks.json"), self.files[".codex/hooks.json"]
        )
        self.assertEqual(
            self.read(".codex/config.toml"), self.files[".codex/config.toml"]
        )

    def test_trusted_hash_matches_what_codex_accepted(self):
        # codex 0.167.2 の exec が、この値を config.toml に書いたフックを実行した（2026-11-25 に確認）
        group = {
            "matcher": "Bash",
            "hooks": [
                {
                    "type": "command",
                    "command": "/private/tmp/claude-501/-Users-j5ik2o-orca-workspaces-dotfiles-bot-upstream-guard/"
                    "acace11a-89f5-4d10-97c8-12b3e44a00fe/scratchpad/codexhook.sh",
                    "timeout": 10,
                }
            ],
        }
        self.assertEqual(
            ug.codex_trusted_hash(group),
            "sha256:dd90b162a34b0711d2b5d9f9482e1524380931b69d4536644bb96de561a943ac",
        )


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    print(f"判定の表: {len(CASES)} 件")
    sys.exit(0 if result.wasSuccessful() else 1)
