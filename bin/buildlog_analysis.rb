#!/usr/local/bin/ruby
require 'optparse'

# Command line interface for Buildlog Analysis

load 'lib/buildlog_analyzer_dispatcher.rb'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: buildlog_analysis.rb [options]"

  opts.on('-d', '--dir=DIRECTORY', 'Directory with the build logs') do |opt| 
    options[:dir] = opt
  end

  options[:recursive] = false
  opts.on("-r", "--recursive", "Exhaustively goes through all directories in search of buildlogs") do |opt|
   options[:recursive] = opt
  end

  options[:verbose] = false
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |opt| 
    options[:verbose] = opt 
  end
end

begin
  optparse.parse!
  mandatory = [:dir]
  missing = mandatory.select{ |param| options[param].nil? }
  raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?
  dispatcher = BuildlogAnalyzerDispatcher.new(options[:dir], options[:recursive], options[:verbose])
  dispatcher.start
rescue OptionParser::ParseError => e
  puts e
  puts optparse
  exit
end