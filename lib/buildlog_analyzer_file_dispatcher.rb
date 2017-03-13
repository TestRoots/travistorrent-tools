require 'csv'

load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_log_file_analyzer_dispatcher.rb'
load 'lib/languages/ruby_log_file_analyzer.rb'
load 'lib/csv_helper.rb'

# Takes a path to a logfile of Travis CI logfiles (named *.log) and tries to dispatch the analysis of the logfiles
# to the most specific analyzer. When called with  enabled, exhaustively goes through all directories in search
# of buildlogs.

class BuildlogAnalyzerFileDispatcher
  @logfileforanalysis
  @results

  def initialize(logfileforanalysis)
    @logfileforanalysis = logfileforanalysis
    @results = Array.new
  end

  def start
    #puts "Starting to analyze buildlogs #{@logfileforanalysis} ..."

    begin
      file = "#{@logfileforanalysis}"

      if File.directory?(file)
        b = BuildlogAnalyzerDispatcher.new file, true
        b.start
      end

      if File.extname(@logfileforanalysis) != '.log'
        return
      end

      #puts "Working on #{file}"

      analyzer = LogFileAnalyzer.new file
      analyzer.mixin_specific_language_analyzer
      analyzer.init
      analyzer.analyze
      @results << analyzer.output
    rescue Exception => e
      puts "Error analyzing #{file}, rescued: #{e}"
    end

    if !@results.empty?
      csv = array_of_hashes_to_csv_without_header @results
      puts csv
    end

  end
end