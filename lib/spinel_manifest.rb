# Spinelfile parser — spinel-vendor / spinel-lock 共通モジュール
#
# Spinelfile は純 Ruby DSL:
#   spinel "0.1"
#   use "owner/repo", sha: "abc1234"
#   use "owner/repo", tag: "v1.0"
#   use "owner/repo", branch: "main"
#   use "git+http://tatami.internal/git/foo.git", sha: "..."

class SpinelManifest
  SPEC_VERSION = "0.1"

  attr_reader :deps

  def initialize
    @deps = []
    @spec_version = nil
  end

  def self.load(path = "Spinelfile")
    m = new
    return m unless File.exist?(path)
    m.instance_eval(File.read(path), path)
    m
  end

  # DSL
  def spinel(v); @spec_version = v; end

  def use(name, sha: nil, tag: nil, branch: nil, url: nil)
    @deps << {
      name: name,
      sha: sha,
      tag: tag,
      branch: branch,
      url: url || default_url_for(name),
    }
  end

  private

  def default_url_for(name)
    "https://github.com/#{name}.git"
  end
end

# GitHub style "user/repo" → "user__repo"
# git+url style → URL の最後の path 要素
def vendor_dir_for(name)
  if name =~ /\Agit\+/
    name.split("/").last.sub(/\.git\z/, "").gsub("/", "__")
  else
    name.sub("/", "__")
  end
end
