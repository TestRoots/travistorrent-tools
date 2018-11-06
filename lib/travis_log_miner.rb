#!/usr/bin/env ruby

# Occassionally, Travis fails to include. This is a never-give-up safeguard against such behavior
def include_travis
  begin
    require 'travis'
  rescue
    error_message = "Error: Problem including Travis. Retrying ..."
    puts error_message
    sleep 2
    include_travis
  end
end

include_travis
require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'time'
require 'fileutils'
require "logger"

load 'lib/csv_helper.rb'


class TravisLogMiner

  @slug
  @directory
  @date_threshold
  @buildlogs
  @parent_dir
  @logger

  def initialize(slug, directory, date_threshold, buildlogs)
    @slug = slug
    @directory = directory
    @date_threshold = date_threshold
    @buildlogs = buildlogs

    # Prepare the project folder
    @parent_dir = File.join(@directory, '/build_logs/', @slug.gsub(/\//, '@'))
    FileUtils::mkdir_p(@parent_dir)

    init_log
  end

  def init_log
    log_file_name = "#{Dir.pwd}/logs/TravisLogMiner.log"
    unless File.exist?(File.dirname(log_file_name))
      FileUtils.mkdir_p(File.dirname(log_file_name))
      File.new(log_file_name, 'w')
    end

    @logger = Logger.new(log_file_name, 'monthly')

    # logs for program TravisLogMiner
    @logger.progname = 'TravisLogMiner'

    @logger.formatter = proc do |severity, datetime, progname, msg|
      %Q|{timestamp: "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}", severity: "#{severity}", message: "#{msg}"}\n|
    end
  end

  def download_job(job, logname, wait_in_s = 1)
    if (wait_in_s > 64)
      @logger.error("Error: Giveup: We can't wait forever for #{job}")
      return 0
    elsif (wait_in_s > 1)
      sleep wait_in_s
    end

    begin
      log_url = "https://api.travis-ci.org/v3/job/#{job}/log.txt"
      begin
        @logger.info("Attempt 1 #{log_url}")
        log = Net::HTTP.get_response(URI.parse(log_url)).body
      rescue
        # Workaround if log.body results in error
        @logger.info("Attempt 2 #{log_url}")
        log = Net::HTTP.get_response(URI.parse(log_url)).body
      end

      File.open(logname, 'w') { |f| f.puts log }
      log = '' # necessary to enable GC of previously stored value, otherwise: memory leak
    rescue
      @logger.error("Retrying, but Could not get log #{logname}")
      download_job(job, wait_in_s*2)
    end
  end

  def job_logs(build, sha)
    jobs = build.job_ids
    jobs.each do |job|
      logname = File.join(@parent_dir, "#{build.number}_#{build.id}_#{sha}_#{job}.log")
      next if File.exists?(logname) and File.size(logname) > 1
      download_job(job, logname)
    end
  end

  def get_build(build, wait_in_s = 1)
    if (wait_in_s > 64)
      @logger.error("Error: Giveup: We can't wait forever for #{build}")
      return {}
    elsif (wait_in_s > 1)
      sleep wait_in_s
    end

    begin
      begin
        # Here, We just want the logs that are in a range of date.
        # A log must be start and finish until "my date"
        # If the user don't pass, we consider all logs
        started_at = nil
        ended_at = nil

        # Some times we don't have the start date
        if !build.started_at.nil?
          started_at = Time.parse(build.started_at.to_s).strftime('%F')
          # @logger.info("Comparing #{started_at} > #{@date_threshold}: " + (started_at >= @date_threshold ? "true" : "false"))
          return {} if started_at > @date_threshold
        end

        if !build.finished_at.nil?
          ended_at = Time.parse(build.finished_at.to_s).strftime('%F')
          # @logger.info("Comparing #{ended_at} >= #{@date_threshold}: " + (ended_at >= @date_threshold ? "true" : "false"))
          return {} if ended_at > @date_threshold
        end
      rescue Exception => e
        @logger.error("Skipping empty date. Build id: #{build.id} - Build number: #{build.number} - Started at: #{build.started_at} - Finished at: #{build.finished_at} - Error Message: #{e.message}")
        return {}
      end

      # Get the log based on the build and the associate commit
      job_logs(build, build.commit.sha) if @buildlogs

      build_data = {
        :repository_id => build.repository_id,
        :build_id => build.id,
        :commit => build.commit.sha,
        :pull_request => build.pull_request,
        :pull_request_number => build.pull_request_number,
        :branch => build.commit.branch,

        # [doc] The build status (such as passed, failed, ...) as returned from the Travis CI API.
        :status => build.state,

        # [doc] The full build duration as returned from the Travis CI API.
        :duration => build.duration,
        :started_at => started_at,
        :finished_at => ended_at,

        # [doc] The unique Travis IDs of the jobs
        :jobs => build.job_ids
      }

      return build_data
    rescue Exception => e
      @logger.error("Retrying, but Error getting Travis build #{build['id']}: #{e.message}")
      return get_build(build, wait_in_s*2)
    end
  end

  # Get the build logs
  def get_travis(wait_in_s = 1)
    if (wait_in_s > 128)
      @logger.error("Error: Giveup: We can't wait forever for #{@slug}")
      return 0
    elsif (wait_in_s > 1)
      sleep wait_in_s
    end

    begin
      all_builds = []
      repository = Travis::Repository.find(@slug)

      highest_build = repository.last_build_number.to_i
      @logger.info("[START] Harvesting Travis build logs for #{@slug} (#{highest_build} builds)")

      repository.each_build(after_number: repository.last_build_number.to_i)  do |build|
        all_builds << get_build(build)
      end

      all_builds.flatten!
      # Remove empty entries
      all_builds.reject! { |c| c.empty? }
      # Remove duplicates
      all_builds = all_builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }

      if all_builds.empty?
        @logger.error("Error could not get any repo information for #{@slug}.")
        exit(1)
      end

      # Save the builds in a JSON file
      json_file = File.join(@parent_dir, 'repo-data-travis.json')
      File.open(json_file, 'w') do |f|
        f.puts JSON.pretty_generate(all_builds)
      end

      # Save the builds in a CSV file
      csv_file = File.join(@parent_dir, 'repo-data-travis.csv')
      File.open(csv_file, 'w') do |f|
        f.puts all_builds.first.keys.map { |x| x.to_s }.join(',')
        all_builds.sort { |a, b| b[:build_id]<=>a[:build_id] }.each { |x| f.puts x.values.join(',') }
      end

      @logger.info("[FINISH] Harvesting Travis build logs for #{@slug} (#{highest_build} builds)")
    end
  end
end
