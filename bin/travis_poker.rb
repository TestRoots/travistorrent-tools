# (c) 2015 -- onwards Moritz Beller <moritz.beller@gmail.com>
#
# MIT licensed -- see top level dir


require 'travis'
require 'net/http'
require 'csv'

def travis_builds_for_project(repo)
  begin
    repository = Travis::Repository.find(repo)
    return repository.last_build_number.to_i
  rescue Exception => e
    return 0
  end
end


def analyze_projects_on_travis
  i = 0
  File.open('results.csv', 'w') { |file|
    CSV.foreach(ARGV[0]) do |row|
      curRow = row
      curRow << travis_builds_for_project("#{row[0]}/#{row[1]}").to_s
      file.write(curRow.to_csv)
      i += 1
      file.flush if i%50 == 0
    end
  }

end

analyze_projects_on_travis