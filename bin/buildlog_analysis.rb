#!/usr/local/bin/ruby

# Command line interface for Buildlog Analysis

load 'lib/buildlog_analyzer_dispatcher.rb'

recurse = false

if (ARGV[0].nil?)
  puts 'Missing argument(s)!'
  puts ''
  puts 'usage: buildlog_analyzer_dispatcher.rb directory [-r]'
  exit(1)
end

recurse = true if ARGV[1] == "-r"
directory = ARGV[0]

dispatcher = BuildlogAnalyzerDispatcher.new(directory, recurse)
dispatcher.start