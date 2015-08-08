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
  i = 0
  File.open('results.csv', 'w') { |file|
    CSV.foreach(ARGV[0]) do |row|
      curRow = row
      curRow << is_project_active_on_travis("#{row[0]}/#{row[1]}").to_s
      file.write(curRow.to_csv)
      i += 1
      file.flush if i%50 == 0
    end
  }

end

analyze_projects_on_travis