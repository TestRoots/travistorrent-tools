#!/usr/bin/env ruby

file = ARGV[0]

file_contents = File.new(file).readlines

file_contents.each do |line|
  line.strip!
  index = file_contents.find_index(line)
  unless (line =~ /# \[doc\] (.+)/).nil?
    doc = $1
    while (index <= file_contents.length)
      next_line = file_contents[index+1]
      break if next_line.nil?
      next_line.strip!
      doc += " #{$1}" if !(next_line =~ /# (.+)/).nil?
      if !(next_line =~ /(.+) =>/).nil?
        puts "| `#{$1.tr(':','')}` | #{doc} |"
        break;
      end
      index += 1
    end
  end
end