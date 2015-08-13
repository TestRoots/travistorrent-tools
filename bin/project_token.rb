#!/usr/bin/env ruby


if (ARGV[0].nil? || ARGV[1].nil?)
  msg =<<-MSG
  Given a file with project names and a file of GitHub token,
  assign each project a token in a fair manner

  usage: project_token.rb project-names tokens
  MSG
  puts msg
  exit(1)
end

projects = File.open(ARGV[0]).readlines
tokens = File.open(ARGV[1]).readlines

token_idx = 0

projects.each do |project|
  puts "#{project.strip} #{tokens[token_idx]}"
  if token_idx >= tokens.size - 2
    token_idx = 0
  end
  token_idx += 1
end
