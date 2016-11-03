#!/usr/bin/env ruby

require 'travis'
require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'time'
require 'fileutils'

load 'lib/csv_helper.rb'

@date_threshold = Date.parse("2016-09-01")

def job_logs(build, error_file, parent_dir)
  jobs = build.jobs
  jobs.each do |job|
    name = File.join(parent_dir, "#{build.id}_#{build.commit.sha}_#{job.id.to_s}.log")
    next if File.exists?(name)

    begin
      begin
        # Give Travis CI some time before trying once more
        log = job.log.body
      rescue
        begin
          log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
          STDERR.puts "Attempt 2 #{log_url}"
          log = Net::HTTP.get_response(URI.parse(log_url)).body
        rescue
          # Workaround if log.body results in error.
          log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
          STDERR.puts "Attempt 3 #{log_url}"
          log = Net::HTTP.get_response(URI.parse(log_url)).body
        end
      end

      File.open(name, 'w') { |f| f.puts log }
      log = '' # necessary to enable GC of previously stored value, otherwise: memory leak
    rescue
      error_message = "Could not get log #{name}"
      puts error_message
      File.open(error_file, 'a') { |f| f.puts error_message }
      next
    end
  end
end

def get_travis(repo, build_logs = true)
  parent_dir = File.join('build_logs/rubyjava/', repo.gsub(/\//, '@'))
  error_file = File.join(parent_dir, 'errors')
  FileUtils::mkdir_p(parent_dir)
  json_file = File.join(parent_dir, 'repo-data-travis.json')

  all_builds = []
  all_builds = JSON.parse(File.read(json_file)).to_a

  begin
    repository = Travis::Repository.find(repo)

    puts "Harvesting Travis build logs for #{repo}"
    highest_build = repository.last_build_number.to_i
    while true do
      highest_build = highest_build + 1
      if highest_build % 25 == 0
        break
      end
    end

    repo_id = JSON.parse(open("https://api.travis-ci.org/repos/#{repo}").read)['id']

    (0..highest_build).select { |x| x % 25 == 0 }.reverse_each do |last_build|

      url = "https://api.travis-ci.org/builds?after_number=#{last_build}&repository_id=#{repo_id}"
      STDERR.puts url

      resp = open(url,
                  'Content-Type' => 'application/json',
                  'Accept' => 'application/vnd.travis-ci.2+json')
      builds = JSON.parse(resp.read)
      builds['builds'].each do |build|
        begin
          started_at = (Time.parse(build).utc.to_s)
          next if Date.parse(started_at) >= @date_threshold

          job_logs(build, error_file, parent_dir) if build_logs
          commit = builds['commits'].find { |x| x['id'] == build['commit_id'] }

          build_data = {
              :build_id => build['id'],
              :commit => commit['sha'],
              :pull_req => build['pull_request_number'],
              :branch => commit['branch'],
              :status => build['state'],
              :duration => build['duration'],
              :started_at => started_at, # in UTC
              :jobs => build['job_ids'],
              #:jobduration => build.jobs.map { |x| "#{x.id}##{x.duration}" }
              :event_type => build['event_type']
          }

          next if build_data.empty?
          all_builds << build_data
        rescue Exception => e
          error_message = "Error getting Travis builds for #{repo} #{build['id']}: #{e.message}"
          puts error_message
          File.open(error_file, 'a') { |f| f.puts error_message }
        end
      end
    end
  rescue Exception => e
    error_message = "Error getting Travis builds for #{repo}: #{e.message}"
    puts error_message
    File.open(error_file, 'a') { |f| f.puts error_message }
  end

  # Remove duplicates
  all_builds = all_builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }

  File.open(json_file, 'w') do |f|
    f.puts JSON.dump(all_builds)
  end

  csv_file = File.join(parent_dir, 'repo-data-travis.csv')
  File.open(csv_file, 'a') do |f|
    f.puts all_builds.first.keys.map { |x| x.to_s }.join(',') if (File.size(csv_file) < 2)
    all_builds.sort { |a, b| b[:build_id]<=>a[:build_id] }.each { |x| f.puts x.values.join(',') }
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

get_travis("#{owner}/#{repo}", false)
