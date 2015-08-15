# Receives the language and a project directory and tries to dispatch the analysis of the logfiles to the correct
# analyzers
require 'csv'

load 'log_file_analyzer.rb'
load 'languages/java_log_file_analyzer_dispatcher.rb'
load 'languages/ruby_log_file_analyzer.rb'

if (ARGV[0].nil? || ARGV[1].nil?)
  puts 'Missing argument(s)!'
  puts ''
  puts 'usage: buildlog_analyzer_dispatcher.rb directory lang'
  exit(1)
end


directory = ARGV[0]
lang = ARGV[1]

results = Array.new

# dir foreach is much faster than Dir.glob, because the latter builds an array of matched files up-front
Dir.foreach(directory) do |logfile|
  next if logfile == '.' or logfile == '..' or File.extname(logfile) != '.log'

  file = "#{directory}/#{logfile}"
  if lang == 'Ruby'
    analyzer = RubyLogFileAnalyzer.new file
  elsif lang == 'Java'
    analyzer = JavaLogFileAnalyzerDispatcher.new file
  else
    next
  end

  analyzer.analyze
  results << analyzer.output
end

def array_of_hashes_to_csv(array_of_hashes)
  CSV.generate do |csv|
    csv << array_of_hashes.first.keys
    array_of_hashes.each { |hash| csv << hash.values }
  end
end

if !results.empty?
  csv = array_of_hashes_to_csv results
  File.open("#{directory}/repo-data-travis.csv", 'w') { |file|
    file.puts csv
  }
end
