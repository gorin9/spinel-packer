require 'tmpdir'
require 'fileutils'
ARGV.replace(['version'])
load File.expand_path('../spinel-packer', __dir__)
def assert(x,m);raise m unless x;end
Dir.mktmpdir do |dir|
  File.write(dir+'/a','x');File.write(dir+'/b','yz');first=compute_tree_sha(dir)
  File.write(dir+'/a','xy');File.write(dir+'/b','z');second=compute_tree_sha(dir)
  assert(first!=second,'file boundaries')
  File.rename(dir+'/a',dir+'/c');third=compute_tree_sha(dir);assert(second!=third,'names')
  File.write(dir+'/.hidden','x');assert(third!=compute_tree_sha(dir),'dotfiles')
  File.write(dir+'/main.rb', "require_relative 'missing'\n")
  begin;inline_requires(dir+'/main.rb', +'');raise 'missing accepted';rescue LoadError;end
  Dir.chdir(dir) do
    File.write('Spinelfile', "spinel \"0.1\"\nuse \"gorin9/spnl-web\", sha: \"#{'a'*40}\"\n")
    cmd_migrate([]);assert(File.read('spin.lock').include?('ref = "'+('a'*40)+'"'),'pinned migration')
  end
end
puts 'tree identity, hidden files, missing dependencies and migration passed'
Dir.mktmpdir do |dir|
  source=File.join(dir,'source');FileUtils.mkdir_p(source)
  run('git','init','-q',source)
  File.write(source+'/a','original')
  Dir.chdir(source) do
    run('git','add','a')
    run('git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture')
  end
  sha=run('git','-C',source,'rev-parse','HEAD').strip
  app=File.join(dir,'app');FileUtils.mkdir_p(app)
  Dir.chdir(app) do
    File.write('Spinelfile',"spinel \"0.2\"\nuse \"test/lib\", sha: #{sha.inspect}, url: #{source.inspect}\n")
    fetch_to_vendor('test/lib',source,sha);write_lock_file
    File.write('vendor/test__lib/a','drift')
    install_strict_from_lock
    assert(File.read('vendor/test__lib/a')=='original','strict restoration')
    begin
      fetch_to_vendor('test/lib',source,'f'*40);raise 'bad commit accepted'
    rescue SystemExit
    end
    assert(File.read('vendor/test__lib/a')=='original','failed fetch preserves vendor')
  end
end
puts 'local-Git locked restoration and failed-fetch recovery passed'
if ENV['SPIN_PROGRAM']
  Dir.mktmpdir do |dir|
    source=File.join(dir,'source');app=File.join(dir,'app')
    FileUtils.mkdir_p(source);FileUtils.mkdir_p(app)
    run('git','init','-q',source)
    File.write(source+'/lib.rb',"module Lib; end\n")
    Dir.chdir(source) do
      run('git','add','lib.rb')
      run('git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture')
    end
    sha=run('git','-C',source,'rev-parse','HEAD').strip
    Dir.chdir(app) do
      File.write('Spinelfile',"spinel \"0.1\"\nuse \"test/lib\", sha: #{sha.inspect}\n")
      cmd_migrate([])
      config={'GIT_CONFIG_COUNT'=>'1','GIT_CONFIG_KEY_0'=>"url.#{source}.insteadOf",'GIT_CONFIG_VALUE_0'=>'https://github.com/test/lib.git','XDG_CACHE_HOME'=>File.join(dir,'cache')}
      raise 'official spin lock failed' unless system(config,ENV.fetch('SPIN_PROGRAM'),'lock')
      assert(File.read('spin.lock').include?(sha),'official tool preserved migrated SHA')
    end
  end
  puts 'official spin consumes migrated manifest/lock passed'
end
