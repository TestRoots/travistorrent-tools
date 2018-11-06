#!/usr/bin/env ruby

require 'optparse'

# Command line interface for Buildlog Harvester

load 'lib/travis_log_miner.rb'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: buildlog_analysis.rb [options]"

  opts.on('-s', '--slug=SLUG', '[REQUIRED] Repository slug (owner/repository') do |opt|
    options[:slug] = opt
  end

  # The user can pass a directory where the build logs will be saved
  options[:dir] = Dir.pwd
  opts.on('-d', '--dir=DIRECTORY', '[OPTIONAL] Directory to save the build logs') do |opt|
    options[:dir] = opt
  end

  # The date limit is the most recent build log
  options[:date] = Time.now.strftime('%F')
  opts.on('-t', '--threshold=DATA_LIMIT', '[OPTIONAL] Date Threshold in format YYYY-MM-DD, otherwise it will be used the most recent date (now)') do |opt|
    options[:date] = opt
  end

  # If the user just want to get the builds status
  options[:buildlogs] = true
  opts.on("-l", "--buildlogs", "[OPTIONAL] Download build logs (download by pattern)") do |opt|
    options[:buildlogs] = opt
  end
end

begin
  optparse.parse!
  mandatory = [:slug]
  missing = mandatory.select{ |param| options[param].nil? }
  raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?
  miner = TravisLogMiner.new(options[:slug], options[:dir], options[:date], options[:buildlogs])
  miner.get_travis
rescue OptionParser::ParseError => e
  puts e
  puts optparse
  exit
end
