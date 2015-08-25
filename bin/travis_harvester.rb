#!/usr/bin/env ruby

require 'travis'
require 'net/http'

load 'lib/csv_helper.rb'

def get_travis(repo)
  parent_dir = File.join('build_logs', repo.gsub(/\//, '@'))
  save_file = File.join(parent_dir, 'repo-data-travis.csv')
  error_file = File.join(parent_dir, 'errors')
  FileUtils::mkdir_p(parent_dir)

  begin
    repository = Travis::Repository.find(repo)

    puts "Harvesting Travis build logs for #{repo}"
    highest_build = repository.last_build_number
    repository.each_build do |build|
      begin
        jobs = build.jobs
        jobs.each do |job|
          name = File.join(parent_dir, build.id + '_' + build.commit.sha + '_' + job.id.to_s + '.log')
          next if File.exists?(name)

          begin
            begin
              log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
              log = Net::HTTP.get_response(URI.parse(log_url)).body
            rescue
              begin
                # Give Travis CI some time before trying once more
                log = job.log.body
              rescue
                # Workaround if log.body results in error.
                log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job.id}/log.txt"
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

        keys = ['build_id', 'commit', 'pull_req', 'branch', 'status', 'duration', 'started_at', 'jobs', 'jobduration']
        values = [
            build.id,
            build.commit.sha,
            build.pull_request_number,
            build.commit.branch,
            build.state,
            build.duration,
            build.started_at,
            build.jobs.map { |x| x.id },
            build.jobs.map { |x| "#{x.id}##{x.duration}"}
        ]
        build_data = Array.new
        build_data << Hash[keys.zip values]

        next if build_data.empty?

        if !File.exists? save_file
          # write out header
          File.open(save_file, 'w') { |f| f.puts array_of_hashes_to_csv build_data }
        else
          # write in append mode without header
          File.open(save_file, 'a') { |f| f.puts array_of_hashes_to_csv_without_header build_data }
        end
      rescue Exception => e
        error_message = "Error getting Travis builds for #{repo} #{build.id}: #{e.message}"
        puts error_message
        File.open(error_file, 'a') { |f| f.puts error_message }
      end
    end
  rescue Exception => e
    error_message = "Error getting Travis builds for #{repo}: #{e.message}"
    puts error_message
    File.open(error_file, 'a') { |f| f.puts error_message }
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
