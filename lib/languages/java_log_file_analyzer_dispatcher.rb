# (c) 2015 -- onwards Moritz Beller <moritz.beller@gmail.com>
#
# MIT licensed -- see top level dir


load 'lib/languages/java_ant_log_file_analyzer.rb'
load 'lib/languages/java_maven_log_file_analyzer.rb'
load 'lib/languages/java_gradle_log_file_analyzer.rb'

# A wrapper that decides what is the correct sub Java analyzer to call by quickly browsing through its contents.
# This has minimal overhead compared to directly calling the correct sub analyzer through lazy initializing the
# loaded file, and is far better than trying every existing sub-analyzer and seeing which one worked
class JavaLogFileAnalyzerDispatcher
  @wrappedAnalyzer

  def initialize(file, content)
    if content.scan(/(Reactor Summary|mvn test)/m).size >= 2
      @wrappedAnalyzer = JavaMavenLogFileAnalyzer.new file
    elsif content.scan(/gradle/m).size >= 2
      @wrappedAnalyzer = JavaGradleLogFileAnalyzer.new file
    elsif content.scan(/ant/m).size >= 2
      @wrappedAnalyzer = JavaAntLogFileAnalyzer.new file
    else
      # default back to Ant if nothing else found
      @wrappedAnalyzer = JavaAntLogFileAnalyzer.new file
    end
  end

  def output
    @wrappedAnalyzer.output
  end

  def analyze
    @wrappedAnalyzer.analyze
  end
end