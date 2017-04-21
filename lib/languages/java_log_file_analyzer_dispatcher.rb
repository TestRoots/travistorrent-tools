load 'lib/languages/java_ant_log_file_analyzer.rb'
load 'lib/languages/java_maven_log_file_analyzer.rb'
load 'lib/languages/java_gradle_log_file_analyzer.rb'

# A Mixin-dispatcher for Java-based logs that decides what is the correct sub Java analyzer by quickly browsing through
# the log contents. This has minimal overhead compared to directly calling the correct sub analyzer through lazy
# initializing the loaded file, and is far better than trying every existing sub-analyzer and seeing which one worked

module JavaLogFileAnalyzerDispatcher

  def init
    if @logFile.scan(/(Reactor Build Order|mvn test)/m).size >= 1
      self.extend JavaMavenLogFileAnalyzer
    elsif @logFile.scan(/gradle/m).size >= 2
      self.extend JavaGradleLogFileAnalyzer
    elsif @logFile.scan(/ant/m).size >= 2
      # self.extend JavaAntLogFileAnalyzer
      self.extend JavaMavenLogFileAnalyzer
    else
      # default back to Ant if nothing else found
      self.extend JavaAntLogFileAnalyzer
    end

    init_deep
  end
end
