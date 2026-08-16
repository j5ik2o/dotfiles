{ ... }:

# Tailscale 経由で `herdr --remote <host>` を使うため、macOS の Remote Login (sshd) を有効化する。
# nix-darwin に sshd を管理するオプションが無いので activation script で launchd を直接操作する。
# `systemsetup -setremotelogin` は Full Disk Access (TCC) を要求するため使わない。
{
  system.activationScripts.postActivation.text = ''
    echo "🔐 Remote Login (sshd) を確認中..."

    if launchctl print-disabled system | grep -q '"com.openssh.sshd" => disabled'; then
      echo "  → com.openssh.sshd を enable します"
      launchctl enable system/com.openssh.sshd
    fi

    # System Settings の Remote Login トグルは SSH ACL グループ (com.apple.access_ssh) を
    # 併せて構成するが、launchctl 経由の有効化では構成されない。
    # このグループが存在して空だと、正しいパスワードでも全ユーザーが拒否される。
    if ! dseditgroup -o read com.apple.access_ssh >/dev/null 2>&1; then
      echo "  → SSH ACL グループ com.apple.access_ssh を作成します"
      dseditgroup -o create com.apple.access_ssh
    fi
    if ! dseditgroup -o read com.apple.access_ssh | grep -q 'CDEF00000050'; then
      echo "  → SSH ACL に admin グループを追加します"
      dseditgroup -o edit -a admin -t group com.apple.access_ssh
    fi

    if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
      echo "✅ Remote Login は有効です"
    else
      echo "  → com.openssh.sshd を bootstrap します"
      # bootstrap 失敗は apply 全体を止めずに警告に留める。
      # TCC やプロファイル制限で失敗しうるが、その場合は
      # System Settings > General > Sharing > Remote Login で手動有効化すればよい。
      if launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist; then
        echo "✅ Remote Login を有効化しました"
      else
        echo "⚠️  Remote Login の自動有効化に失敗しました。"
        echo "    System Settings > General > Sharing > Remote Login を手動で ON にしてください。"
      fi
    fi
  '';
}
