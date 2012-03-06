task :env do
  home = ENV['FLEX_HOME']

  if home && File.exist?("#{home}/bin")
    ENV['PATH'] += ":#{home}/bin"
  end

  if(`which mxmlc`.strip.empty?)
    raise "Unable to find mxmlc. Please put your flex sdk on the path, or set FLEX_HOME"
  end
end

task :build => :env do
  sh "mxmlc -incremental -compiler.library-path+=MonsterDebugger.swc src/FlashCanvas.as -output bin/flashcanvas.swf"
end

task :copy do
  to = File.expand_path("~/dev/blake/caper/vendor/assets/javascripts/flashcanvas")
  sh "cp bin/flashcanvas.swf #{to}"
end

task :default => [:build, :copy]
