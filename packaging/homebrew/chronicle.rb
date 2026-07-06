# Homebrew formula template for Chronicle.
# Published to the chronicle-dev/homebrew-tap repository by the release workflow;
# `url` and `sha256` are filled in per release.
class Chronicle < Formula
  desc "Privacy-first activity journal for macOS"
  homepage "https://github.com/chronicle-dev/chronicle"
  url "https://github.com/chronicle-dev/chronicle/releases/download/vVERSION/chronicle-VERSION-macos-universal.tar.gz"
  sha256 "SHA256_PLACEHOLDER"
  license "MIT"
  version "VERSION"

  depends_on macos: :sonoma

  def install
    bin.install "bin/chronicle"
    bin.install "bin/chronicled"
    zsh_completion.install "completions/_chronicle"
    bash_completion.install "completions/chronicle.bash"
    fish_completion.install "completions/chronicle.fish"
  end

  def caveats
    <<~EOS
      Start the background agent with:
        chronicle daemon install

      Some modules need macOS permissions (Accessibility, Full Disk Access).
      Run `chronicle doctor` to check.
    EOS
  end

  test do
    assert_match "chronicle", shell_output("#{bin}/chronicle version")
  end
end
