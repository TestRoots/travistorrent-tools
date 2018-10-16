# A Mixin for the analysis of Ant build files. Also provides resonable default behavior for all Java-based logs.

module JavaAntLogFileAnalyzer
  attr_reader :tests_failed, :pure_build_duration

  def init_deep
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'java-ant'
  end

  def custom_analyze
    extract_tests
    analyze_tests

    getOffendingTests
  end

  def extract_tests
    test_section_started = false
    reactor_started = false
    line_marker = 0
    current_section = ''

    # Possible future improvement: We could even get all executed tests (also the ones which succeed)
    @folds[@OUT_OF_FOLD].content.each do |line|
      if !(line =~ /\[(junit|testng|test.*)\] /).nil?
        test_section_started = true
      elsif !(line =~ /Total time: (.+)/i).nil?
        @pure_build_duration = convert_ant_time_to_seconds($1)
      end

      if test_section_started
        @test_lines << line
      end
    end
  end

  def convert_ant_time_to_seconds(string)
    if !(string =~ /((\d+)(\.\d*)?) s/).nil?
      return $1.to_f.round(2)
    elsif !(string =~ /(\d+):(\d+) min/).nil?
      return $1.to_i * 60 + $2.to_i
    end
    return 0
  end

  def extractTestName(string)
    string.split(':')[0].split('.')[1]
  end

  def analyze_tests
    failed_tests_started = false

    @test_lines.each do |line|
      if !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*), (Skipped: (\d*), )?Time elapsed: (.*)/).nil?
        init_tests
        add_framework 'junit'
        @tests_run = true
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i + $3.to_i
        @num_tests_skipped += $5.to_i unless $4.nil?
        @test_duration = convert_ant_time_to_seconds($6)
      elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
        init_tests
        add_framework 'testng'
        @tests_run = true
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i
        @num_tests_skipped += $3.to_i
      elsif !(line =~ /Failed tests:/).nil?
        failed_tests_started = true
      elsif !(line =~ /Test (.*) failed/).nil?
        @tests_failed_lines << $1
      end
    end
    uninit_ok_tests
  end

  def getOffendingTests
    @tests_failed_lines.each { |l| @tests_failed << extractTestName(l) }
  end

  def tests_failed?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end