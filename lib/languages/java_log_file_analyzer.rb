class JavaLogFileAnalyzer < LogFileAnalyzer

  def extract_tests
    test_section_started = false
    line_marker = 0

    @folds[OUT_OF_FOLD].content.each do |line|
      if !(line =~ /-------------------------------------------------------/).nil? && line_marker == 0
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
    @test_lines.each do |line|
      if !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*), Skipped: (\d*)/).nil?
        @tests_run = $1
        @tests_failed = $2 + $3
        @tests_ok = @tests_run.to_i - @tests_failed.to_i
        @tests_skipped = $4
      end
    end
  end
end