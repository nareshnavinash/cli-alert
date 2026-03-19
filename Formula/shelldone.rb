# Homebrew formula for shelldone
# To use from a tap: brew install <username>/tap/shelldone
# To test locally:   brew install --build-from-source ./Formula/shelldone.rb

class Shelldone < Formula
  desc "Terminal process completion notifier — OS-native notifications when commands finish"
  homepage "https://github.com/nareshnavinash/shelldone"
  # Stable release URL and sha256 are populated by the release workflow.
  # Until a release tarball exists, use `brew install --HEAD` to install from git.
  # To update after release: brew fetch --force shelldone && brew reinstall shelldone
  url "https://github.com/nareshnavinash/shelldone/archive/refs/tags/v1.3.1.tar.gz"
  sha256 "2fb63fc185b9189c6f434400c3b03f325937419a82361b52b099d5f936ed3540"
  license "MIT"
  head "https://github.com/nareshnavinash/shelldone.git", branch: "main"

  def install
    bin.install "bin/shelldone"
    (lib/"shelldone").install "lib/shelldone.sh", "lib/auto-notify.zsh", "lib/auto-notify.bash",
                              "lib/state.sh", "lib/external-notify.sh", "lib/ai-hook-common.sh",
                              "lib/tui.sh"
    (share/"shelldone/hooks").install Dir["hooks/*.sh"]
    (share/"shelldone").install "VERSION"
    bash_completion.install "completions/shelldone.bash" => "shelldone"
    zsh_completion.install "completions/shelldone.zsh" => "_shelldone"
  end

  def caveats
    <<~EOS
      Add to your shell config (~/.zshrc or ~/.bashrc):

        eval "$(shelldone init zsh)"   # for zsh
        eval "$(shelldone init bash)"  # for bash

      Or run automatic setup:

        shelldone setup

      Optional: install AI CLI notification hooks:

        shelldone setup ai-hooks
        shelldone setup claude-hook
    EOS
  end

  test do
    assert_match "shelldone", shell_output("#{bin}/shelldone version")
  end
end
