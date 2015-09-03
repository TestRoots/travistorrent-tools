require 'csv'

def array_of_hashes_to_csv_without_header(array_of_hashes)
  CSV.generate do |csv|
    array_of_hashes.each { |hash| csv << hash.values }
  end
end

def array_of_hashes_to_csv(array_of_hashes)
  CSV.generate do |csv|
    csv << array_of_hashes.first.keys
    array_of_hashes.each { |hash| csv << hash.values }
  end
end