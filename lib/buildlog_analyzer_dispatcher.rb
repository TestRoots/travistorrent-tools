# Receives the language and a project directory and tries to dispatch the analysis of the logfiles to the correct
# analyzers
require 'csv'

load 'log_file_analyzer.rb'
load 'languages/java_log_file_analyzer_dispatcher.rb'
load 'languages/ruby_log_file_analyzer.rb'

directory = ARGV[0]
lang = ARGV[1]

# dir foreach is much faster than Dir.glob, because the latter builds an array of matched files up-front
Dir.foreach(directory) do |logfile|
  next if logfile == '.' or logfile == '..' or File.extname(logfile) != '.log'

  file = "#{directory}/#{logfile}"
  puts "#{file}"
  if lang == 'Ruby'
    analyzer = RubyLogFileAnalyzer.new file
  elsif lang == 'Java'
    analyzer = JavaLogFileAnalyzerDispatcher.new file
  end

  analyzer.analyze
  puts analyzer.output
end

