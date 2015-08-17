require 'json'
require 'csv'

directory = ARGV[0]

def array_of_hashes_to_csv(array_of_hashes)
  CSV.generate do |csv|
    csv << array_of_hashes.first.keys
    array_of_hashes.each { |hash| csv << hash.values }
  end
end

csv = array_of_hashes_to_csv JSON.parse(File.open("#{directory}/repo-data-travis.json").read)

File.open("#{directory}/repo-data-travis.csv", 'w') { |file|
  file.puts csv
}
