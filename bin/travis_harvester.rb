require 'travis'
require 'net/http'

def get_travis(repo)
  parent_dir = File.join('build_logs', repo.gsub(/\//, '@'))
  save_file = File.join(parent_dir, 'repo-data-travis.json')
  error_file = File.join(parent_dir, 'errors')
  FileUtils::mkdir_p(parent_dir)

  if File.exists?(save_file)
    builds = File.open(save_file, 'r').read
    JSON.parse(builds, :symbolize_names => true)
  else
    begin
      repository = Travis::Repository.find(repo)
    rescue Exception => e
      error_message = "Error getting Travis builds for #{repo}: #{e.message}"
      STDERR.puts error_message
      File.open(error_file, 'a') { |f| f.puts error_message }
      return []
    end

    STDERR.puts "Harvesting Travis build logs for #{repo}"
    highest_build = repository.last_build_number
    builds = []
    repository.each_build do |build|

      STDERR.write "\rBuild id: #{build.number}/#{highest_build}"
      jobs = build.jobs
      jobs.each do |job|
        name = File.join(parent_dir, build.number + '_' + build.commit.sha + '_' + job.id.to_s + '.log')
        next if File.exists? name

        begin
          log = job.log.body
          # Workaround if log.body results in error.
          #log_url = "https://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
          #log = Net::HTTP.get_response(URI.parse(log_url)).body

          File.open(name, 'w') { |f| f.puts log }
        rescue
          error_message = "Could not get #{log_url}"
          STDERR.puts error_message
          File.open(error_file, 'a') { |f| f.puts error_message }
          next
        end
      end

      builds << {
          :build_id => build.id,
          :commit => build.commit.sha,
          :pull_req => build.pull_request_number,
          :branch => build.commit.branch,
          :status => build.state,
          :duration => build.duration,
          :started_at => build.started_at,
          :jobs => build.jobs.map { |x| x.id }
      }

    end
    builds = builds.select { |x| !x.nil? }.flatten
    File.open(save_file, 'w') { |f| f.puts builds.to_json }
    builds
  end
end

if (ARGV[0].nil? || ARGV[1].nil?)
  puts 'Missing argument(s)!'
  puts ''
  puts 'usage: travis_harvester.rb owner repo'
  exit(1)
end

owner = ARGV[0]
repo = ARGV[1]

get_travis("#{owner}/#{repo}")