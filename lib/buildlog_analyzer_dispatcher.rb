# Receives the language and a project directory and tries to dispatch the analysis of the logfiles to the correct
# analyzers
require 'csv'

load 'log_file_analyzer.rb'
load 'languages/java_log_file_analyzer_dispatcher.rb'
load 'languages/ruby_log_file_analyzer.rb'

file = ARGV[0]
lang = ARGV[1]

if lang == 'Ruby'
  analyzer = RubyLogFileAnalyzer.new file
elsif lang == 'Java'
  analyzer = JavaLogFileAnalyzerDispatcher.new file
end

analyzer.analyze
puts analyzer.output