#!/usr/bin/env ruby


# (c) 2015 -- onwards Moritz Beller <moritz.beller@gmail.com>
#
# MIT licensed -- see top level dir



load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_ant_log_file_analyzer.rb'
load 'lib/languages/java_maven_log_file_analyzer.rb'
load 'lib/languages/java_gradle_log_file_analyzer.rb'
load 'lib/languages/ruby_log_file_analyzer.rb'


#a = JavaMavenLogFileAnalyzer.new "dev_logs/TestRoots@watchdog/419_5ad1c6a9311604aa34ca68d91dd8b16c98189a72_60668421.log"
#a = JavaMavenLogFileAnalyzer.new "dev_logs/TestRoots@watchdog/476_a49d782ea2e7f8c22ae5650c6374d151d8165c04_67596271.log"
#a = JavaMavenLogFileAnalyzer.new "dev_logs/TestRoots@watchdog/510_5004d140afc87adcc8ee122f7945ad5da4597f56_74267343.log"
#a = JavaGradleLogFileAnalyzer.new "dev_logs//mockito@mockito/1_asdffs45_12.log"
#a = RubyLogFileAnalyzer.new "dev_logs/TestRoots@watchdog/ruby_510_5004d140afc87adcc8ee122f7945ad5da4597f56_74267343.log"
#a = RubyLogFileAnalyzer.new "dev_logs/rails@rails/r1_ghcommit_75652687.log"
#a = JavaAntLogFileAnalyzer.new "dev_logs/ant@ant/123_ghcom_12.log"
a = JavaAntLogFileAnalyzer.new "dev_logs/ant@ant/failing_ant_tests.log"

a.analyze
puts a.output

