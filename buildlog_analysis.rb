#!/usr/local/bin/ruby


load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_maven_log_file_analyzer.rb'


a = JavaMavenLogFileAnalyzer.new "build_logs/TestRoots@watchdog/476_a49d782ea2e7f8c22ae5650c6374d151d8165c04_67596271.log"
a.analyze
a.output
