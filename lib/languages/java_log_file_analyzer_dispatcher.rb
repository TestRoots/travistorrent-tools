load 'languages/java_ant_log_file_analyzer.rb'
load 'languages/java_maven_log_file_analyzer.rb'
load 'languages/java_gradle_log_file_analyzer.rb'

# A wrapper that decides what is the correct sub Java analyzer to call by quickly browsing through its contents.
# This has minimal overhead compared to directly calling the correct sub analyzer through lazy initializing the
# loaded file, and is far better than trying every existing sub-analyzer and seeing which one worked
class JavaLogFileAnalyzerDispatcher
  @wrappedAnalyzer

  def initialize(file)
    logFile = File.read(file)
    logFile = logFile.encode(logFile.encoding, :universal_newline => true)

    if logFile.scan(/Reactor Summary/m).size >= 1
      puts "maven!"
      @wrappedAnalyzer = JavaMavenLogFileAnalyzer.new file
    elsif logFile.scan(/gradle/m).size >= 2
      puts "gradle!"
      @wrappedAnalyzer = JavaGradleLogFileAnalyzer.new file
    elsif logFile.scan(/ant/m).size >= 2
      puts "ant!"
      @wrappedAnalyzer = JavaAntLogFileAnalyzer.new file
    else
      puts "unrecognized!"
    end
  end

  def output
    @wrappedAnalyzer.output
  end

  def analyze
    @wrappedAnalyzer.analyze
  end
end