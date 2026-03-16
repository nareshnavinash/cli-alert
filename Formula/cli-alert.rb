# Homebrew formula for cli-alert
# To use from a tap: brew install <username>/tap/cli-alert
# To test locally:   brew install --build-from-source ./Formula/cli-alert.rb

class CliAlert < Formula
  desc "Terminal process completion notifier — OS-native notifications when commands finish"
  homepage "https://github.com/nareshnavinash/cli-alert"
  url "https://github.com/nareshnavinash/cli-alert/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/nareshnavinash/cli-alert.git", branch: "main"

  def install
    bin.install "bin/cli-alert"
    (lib/"cli-alert").install "lib/cli-alert.sh", "lib/auto-notify.zsh", "lib/auto-notify.bash"
    (share/"cli-alert/hooks").install "hooks/claude-done.sh"
    (share/"cli-alert").install "VERSION"
    bash_completion.install "completions/cli-alert.bash" => "cli-alert"
    zsh_completion.install "completions/cli-alert.zsh" => "_cli-alert"
  end

  def caveats
    <<~EOS
      Add to your shell config (~/.zshrc or ~/.bashrc):

        eval "$(cli-alert init zsh)"   # for zsh
        eval "$(cli-alert init bash)"  # for bash

      Or run automatic setup:

        cli-alert setup

      Optional: install Claude Code notification hook:

        cli-alert setup claude-hook
    EOS
  end

  test do
    assert_match "cli-alert", shell_output("#{bin}/cli-alert version")
  end
end
