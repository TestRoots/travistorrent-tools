#!/usr/bin/env ruby

file = ARGV[0]

file_contents = File.new(file).readlines

file_contents.each do |line|
  line.strip!
  index = file_contents.find_index(line)
  unless (line =~ /# \[doc\] (.+)/).nil?
    doc = $1
    next_line = file_contents[index+1]
    break if next_line.nil?
    next_line.strip!
    if !(next_line =~ /(.+) =>/).nil?
      puts "| #{$1} | #{doc} |"
    end

  end
end