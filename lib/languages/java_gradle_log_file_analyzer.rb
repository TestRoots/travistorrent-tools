class JavaMavenLogFileAnalyzer < LogFileAnalyzer
  attr_reader :tests_failed

  def initialize(file)
    super(file)
    @tests_failed = Array.new
  end

  def extract_tests
    test_section_started = false
    line_marker = 0

    @folds[OUT_OF_FOLD].content.each do |line|
      if !(line =~ /:test/).nil? && line_marker == 0
        line_marker = 1
        test_section_started = !test_section_started
      elsif !(line =~ / T E S T S/).nil? && line_marker == 1
        line_marker = 2
      elsif !(line =~ /-------------------------------------------------------/).nil? && line_marker == 2
        line_marker = 0
      end

      if test_section_started
        @test_lines << line
      end
    end
  end

  def analyze_tests
    failed_tests_started = true

    @test_lines.each do |line|
      if (failed_tests_started)
        @tests_failed << line
      end

      if !(line =~ /(\d*) tests completed, (\d*) failed, (\d*) skipped/).nil?
        @num_tests_run = $1
        @num_tests_failed = $2 + $3
        @num_tests_ok = @num_tests_run.to_i - @num_tests_failed.to_i
        @num_tests_skipped = $4
      elsif (line =~ /Failed tests:/).nil?
        failed_test_started = true
      end
    end
  end
end