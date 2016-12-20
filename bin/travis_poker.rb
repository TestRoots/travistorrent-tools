require 'travis'
require 'net/http'
require 'csv'

# Reads in a CSV as first argument. CSV structure login,project,.. as input, and outputs
# login,project,...,num_travisbuilds

@input_csv = ARGV[0]

def travis_builds_for_project(repo, wait_in_s)
  begin
    repository = Travis::Repository.find(repo)
    return repository.last_build_number.to_i
  rescue Exception => e
    STDERR.puts "Exception at #{repo}"
    STDERR.puts e.message
    if (defined? e.io) && e.io.status[0] == "429"
      STDERR.puts "Encountered API restriction: sleeping for #{wait_in_s}"
      sleep wait_in_s
      return travis_builds_for_project repo, wait_in_s*2
    end
    if e.empty?
      return travis_builds_for_project repo, wait_in_s*2
    end
    return 0
  end
end


def analyze_projects_on_travis
  i = 0
  File.open("#{@input_csv}-annotated.csv", 'w') { |file|
    CSV.foreach(@input_csv) do |row|
      curRow = row
      curRow << travis_builds_for_project("#{row[0]}/#{row[1]}", 1).to_s
      file.write(curRow.to_csv)
      i += 1
      file.flush if i%50 == 0
    end
  }

end

analyze_projects_on_travis