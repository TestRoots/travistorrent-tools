#!/usr/local/bin/ruby
require 'optparse'

# Command line interface for Travis Poker

load 'lib/travis_validator.rb'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: travis_poker.rb [options]"

  opts.on('-f', '--file=FILE', '[REQUIRED] CSV file with absolute path') do |opt|
    options[:dir] = opt
  end
end

begin
  optparse.parse!
  mandatory = [:dir]
  missing = mandatory.select{ |param| options[param].nil? }
  raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?
  miner = TravisValidator.new(options[:dir])
  miner.start
rescue OptionParser::ParseError => e
  puts e
  puts optparse
  exit
end