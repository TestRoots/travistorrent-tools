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
require 'csv'
require "logger"

# Reads in a CSV as first argument. CSV structure login,project,.. as input, and outputs
# login,project,...,num_travisbuilds

class TravisValidator

  @input_csv

  def initialize(input_csv)
    @input_csv = input_csv
    @file_name = input_csv.gsub('.csv', '')
    init_log
  end

  def init_log
    log_file_name = "#{Dir.pwd}/logs/TravisValidator.log"
    unless File.exist?(File.dirname(log_file_name))
      FileUtils.mkdir_p(File.dirname(log_file_name))
      File.new(log_file_name, 'w')
    end

    @logger = Logger.new(log_file_name, 'monthly')

    # logs for program TravisLogMiner
    @logger.progname = 'TravisValidator'

    @logger.formatter = proc do |severity, datetime, progname, msg|
      %Q|{timestamp: "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}", severity: "#{severity}", message: "#{msg}"}\n|
    end
  end

  def travis_builds_for_project(repo, wait_in_s)
    begin
      if(wait_in_s > 128)
        @logger.error("We can't wait forever for #{repo}")
        return 0, 0, 0
      elsif(wait_in_s > 1)
        sleep wait_in_s
      end
      repository = Travis::Repository.find(repo)

      # Flags if the repository has or not Travis Build History and if the repository is active
      history = repository.last_build_number.to_i > 0 ? 1 : 0
      active = repository.active ? 1 : 0

      # @logger.info("[STATUS] History: #{history} - Active: #{active}")

      return active, history, repository.last_build_number.to_i
    rescue Exception => e
      @logger.error("Exception at #{repo} - Error Message: #{e.message}")
      if (defined? e.io) && e.io.status[0] == "429"
        @logger.error("Encountered API restriction: next call, sleeping for #{wait_in_s*2}")
        return travis_builds_for_project repo, wait_in_s*2
      end
      if e.message.empty?
        @logger.error("Empty exception, sleeping for #{wait_in_s*2}")
        return travis_builds_for_project repo, wait_in_s*2
      end
      return 0, 0, 0
    end
  end

  def start
    i = 0
    @logger.info("[START] Travis Poker")
    File.open("#{@file_name}-annotated.csv", 'w') { |file|
      file.write("login,name,language,count,active,history,last_build_number\n")
      CSV.foreach(@input_csv, :headers => true) do |row|
        curRow = row

        @logger.info("[STATUS] Line number: #{i} - Analyzing: #{row[0]}/#{row[1]}")

        active, history, last_build_number = travis_builds_for_project("#{row[0]}/#{row[1]}", 1)
        # Workaround to add values to row
        curRow << active.to_s
        curRow << history.to_s
        curRow << last_build_number.to_s
        file.write(curRow.to_csv)
        i += 1
        file.flush if i%50 == 0
      end
    }
    @logger.info("[FINISH] Travis Poker")
  end
end