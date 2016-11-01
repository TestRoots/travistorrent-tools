require 'csv'

load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_log_file_analyzer_dispatcher.rb'
load 'lib/languages/ruby_log_file_analyzer.rb'
load 'lib/csv_helper.rb'

# Takes a path to a directory of Travis CI logfiles (named *.log) and tries to dispatch the analysis of the logfiles
# to the most specific analyzer. When called with recursive enabled, exhaustively goes through all directories in search
# of buildlogs.

class BuildlogAnalyzerDispatcher
  @directory
  @recursive
  @results

  def initialize(directory, recursive)
    @directory = directory
    @recursive = recursive
    @results = Array.new
  end

  def result_file_name
    'buildlog-data-travis.csv'
  end

  def start
    puts "Starting to analyze buildlogs from #{@directory} ..."

    # dir foreach is much faster than Dir.glob, because the latter builds an array of matched files up-front
    Dir.foreach(@directory) do |logfile|
      begin
        next if logfile == '.' or logfile == '..'
        file = "#{@directory}/#{logfile}"

        if @recursive and File.directory?(file)
          b = BuildlogAnalyzerDispatcher.new file, true
          b.start
        end

        next if File.extname(logfile) != '.log'

        puts "Working on #{file}"

        analyzer = LogFileAnalyzer.new file
        analyzer.mixin_specific_language_analyzer
        analyzer.init
        analyzer.analyze
        @results << analyzer.output
      rescue Exception => e
        puts "Error analyzing #{file}, rescued: #{e}"
      end
    end

    if !@results.empty?
      result_file = "#{@directory}/#{result_file_name}"
      puts "  writing #{result_file}"
      csv = array_of_hashes_to_csv @results
      File.open(result_file, 'w') { |file|
        file.puts csv
      }
    end

  end
end