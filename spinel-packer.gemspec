Gem::Specification.new do |s|
  s.name = 'spinel-packer'
  s.version = '0.3.0'
  s.summary = 'Migration and legacy packaging tools for Spinel'
  s.authors = ['gorin9']
  s.homepage = 'https://github.com/gorin9/spinel-packer'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1'
  s.files = Dir['lib/**/*.rb', 'web/**/*.rb', 'spnl_*/**/*.rb', 'spnl_*.rb', 'native/*', 'bin/*', 'README.md', 'LICENSE', 'spin.toml', 'spinel-packer']
  s.require_paths = ['.', 'lib']
  s.bindir = '.'
  s.executables = ['spinel-packer']
end
