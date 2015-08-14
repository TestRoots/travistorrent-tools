#!/usr/local/bin/ruby


load 'lib/log_file_analyzer.rb'
load 'lib/languages/java_maven_log_file_analyzer.rb'


a = JavaMavenLogFileAnalyzer.new "build_logs/TestRoots@watchdog/476_a49d782ea2e7f8c22ae5650c6374d151d8165c04_67596271.log"
a.split
a.anaylze_status
a.anaylze_primary_language

a.extract_tests
a.analyze_tests


puts a.status
puts a.primary_language
puts a.num_tests_ok

a.getOffendingTests
puts a.tests_failed

a.analyze_reactor
puts a.pure_build_duration
puts a.test_duration
puts a.tests_broke_build?
