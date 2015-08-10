#!/usr/local/bin/ruby


load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_log_file_analyzer.rb'


a = JavaLogFileAnalyzer.new "build_logs/TestRoots@watchdog/476_a49d782ea2e7f8c22ae5650c6374d151d8165c04_67596271.log"
a.split
a.anaylze_status
a.anaylze_primary_language

a.extract_tests
a.analyze_tests


puts a.status
puts a.primary_language
puts a.tests_run