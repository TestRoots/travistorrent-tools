require 'travis'
require 'net/http'
require 'csv'

def is_project_active_on_travis(repo)
  begin
    repository = Travis::Repository.find(repo)
    return repository.last_build_number.to_i >= 100
  rescue Exception => e
    return false
  end
end


def analyze_projects_on_travis
  results = Array.new
  CSV.foreach("projects-travis-sorted.txt") do |row|
    curRow = row
    curRow << is_project_active_on_travis("#{row[0]}/#{row[1]}").to_s
    results << curRow.to_csv
  end

  File.open('results.csv', 'w') { |file|
    results.each do |line|
      file.write(line)
    end }

end

analyze_projects_on_travis