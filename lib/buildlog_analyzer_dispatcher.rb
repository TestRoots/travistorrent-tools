# Receives the language and a project directory and tries to dispatch the analysis of the logfiles to the correct
# analyzers
require 'csv'

load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_log_file_analyzer_dispatcher.rb'
load 'lib/languages/ruby_log_file_analyzer.rb'
load 'lib/csv_helper.rb'

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
        analyzer.split
        analyzer.analyze_primary_language
        lang = analyzer.primary_language.downcase

        if lang == 'ruby'
          # add load directive
          # modify ruby log file analyzer such that it extends the methods that we call here
          analyzer.extend(RubyLogFileAnalyzer)
          analyzer.init
        #elsif lang == 'java'
          #analyzer = JavaLogFileAnalyzerDispatcher.new file, analyzer.logFile
        end

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