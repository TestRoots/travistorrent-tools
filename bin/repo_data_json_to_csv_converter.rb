require 'json'
require 'csv'

load 'lib/csv_helper.rb'

directory = ARGV[0]

csv = array_of_hashes_to_csv JSON.parse(File.open("#{directory}/repo-data-travis.json").read)

File.open("#{directory}/repo-data-travis.csv", 'w') { |file|
  file.puts csv
}
