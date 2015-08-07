require 'travis'
require 'net/http'

def get_travis(repo)
  save_file = File.join('cache', repo.gsub(/\//, '-') + '.travis.json')
  if File.exists?(save_file)
    builds = File.open(save_file, 'r').read
    JSON.parse(builds, :symbolize_names => true)
  else
    # Get PR build status from Travis
    begin
      repository = Travis::Repository.find(repo)
    rescue Exception => e
      STDERR.puts "Error getting Travis builds for #{repo}: #{e.message}"
      return []
    end

    STDERR.puts "Getting Travis information for #{repo}"
    builds = []
    repository.each_build do |build|

      STDERR.write "\rBuild id: #{build.number}"
      jobs = build.jobs
      jobs.each do |job|

        parent_dir = File.join('cache', repo.gsub(/\//, '@'))
        name = File.join(parent_dir, build.number + '_' + build.commit.sha + '_' + job.id.to_s + '.log')

        next if File.exists? name

        begin
          #log = job.log.body
          log_url = "https://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
          log = Net::HTTP.get_response(URI.parse(log_url)).body

          FileUtils::mkdir_p(parent_dir)
          File.open(name, 'w') { |f| f.puts log }

        rescue
          STDERR.write "Could not get #{log_url}"
          next
        end
      end

      builds << {
          :build_id => build.id,
          :pull_req => build.pull_request_number,
          :commit => build.commit.sha,
          :branch => build.commit.branch,
          :status => build.state,
          :duration => build.duration,
          :started_at => build.started_at,
          :jobs => build.jobs.map{|x| x.id}
      }

    end
    builds = builds.select { |x| !x.nil? }.flatten
    File.open(save_file, 'w') { |f| f.puts builds.to_json }
    builds
  end
end


owner = ARGV[0]
repo = ARGV[1]

get_travis("#{owner}/#{repo}")