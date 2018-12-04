require 'csv'
require 'json'
require 'date'
require 'time'
require 'fileutils'
require "logger"


load 'lib/log_file_analyzer.rb'
load 'lib/csv_helper.rb'

# Takes a path to a directory of Travis CI logfiles (named *.log) and tries to dispatch the analysis of the logfiles
# to the most specific analyzer. When called with recursive enabled, exhaustively goes through all directories in search
# of buildlogs.

class BuildlogAnalyzerDispatcher
  @directory
  @recursive
  @verbose
  @results

  def initialize(directory, recursive, verbose)
    @directory = directory
    @recursive = recursive
    @verbose = verbose
    @results = Array.new

    init_log
  end

  def init_log
    log_file_name = "#{Dir.pwd}/logs/BuildlogAnalyzerDispatcher.log"
    unless File.exist?(File.dirname(log_file_name))
      FileUtils.mkdir_p(File.dirname(log_file_name))
      File.new(log_file_name, 'w')
    end

    @logger = Logger.new(log_file_name, 'monthly')

    # logs for program TravisLogMiner
    @logger.progname = 'BuildlogAnalyzerDispatcher'

    @logger.formatter = proc do |severity, datetime, progname, msg|
      %Q|{timestamp: "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}", severity: "#{severity}", message: "#{msg}"}\n|
    end
  end

  def result_file_name
    'buildlog-data-travis'
  end

  def start
    @logger.info("Starting to analyze buildlogs from #{@directory} ...")

    # dir foreach is much faster than Dir.glob, because the latter builds an array of matched files up-front
    Dir.foreach(@directory).sort.each do |logfile|
      begin
        next if logfile == '.' or logfile == '..'
        file = "#{@directory}/#{logfile}"

        if @recursive and File.directory?(file)
          b = BuildlogAnalyzerDispatcher.new file, true
          b.start
        end

        next if File.extname(logfile) != '.log'

        @logger.info("Working on #{file}")

        analyzer = LogFileAnalyzer.new file
        analyzer.mixin_specific_language_analyzer
        analyzer.init
        analyzer.analyze

        if @verbose
          @results << analyzer.verbose
        else
          @results << analyzer.output
        end
      rescue Exception => e
        @logger.error("Error analyzing #{file}, rescued: #{e}")
        @logger.error(e.backtrace.join("\n"))
      end
    end

    if !@results.empty?
      result_file = "#{@directory}/#{result_file_name}.csv"
      @logger.info("  writing #{result_file}")
      csv = array_of_hashes_to_csv @results
      File.open(result_file, 'w') { |file|
        file.puts csv
      }

      result_file = "#{@directory}/#{result_file_name}.json"
      @logger.info("  writing #{result_file}")
      File.open(result_file, 'w') do |f|
        f.puts JSON.pretty_generate(@results)
      end

    end

  end
end