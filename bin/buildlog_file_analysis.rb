#!/usr/local/bin/ruby

# Command line interface for Buildlog Analysis

load 'lib/buildlog_analyzer_file_dispatcher.rb'

recurse = false

if (ARGV[0].nil?)
  puts 'Missing argument(s)!'
  puts ''
  puts 'usage: buildlog_analyzer_dispatcher.rb <file>'
  exit(1)
end

logfileforanalysis = ARGV[0]

dispatcher = BuildlogAnalyzerFileDispatcher.new(logfileforanalysis)
dispatcher.start