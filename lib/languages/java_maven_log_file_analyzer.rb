# Supports any test execution with Maven
module JavaMavenLogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  @test_failed_lines

  def init_deep
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'java-maven'
  end

  def custom_analyze
    extract_tests
    analyze_tests

    getOffendingTests
    analyze_reactor
  end

  def extract_tests
    test_section_started = false
    reactor_started = false
    line_marker = 0
    current_section = ''

    # Possible future improvement: We could even get all executed tests (also the ones which succeed)
    @folds[@OUT_OF_FOLD].content.each do |line|
      if !(line =~ /-------------------------------------------------------/).nil? && line_marker == 0
        line_marker = 1
      elsif !(line =~ /\[INFO\] Reactor Summary:/).nil?
        reactor_started = true
        test_section_started = false
      elsif reactor_started && (line =~ /\[.*\]/).nil?
        reactor_started = false
      elsif !(line =~ / T E S T S/).nil? && line_marker == 1
        line_marker = 2
      elsif (line_marker == 1)
        line =~ /Building ([^ ]*)/
        if (!$1.nil? && !$1.strip.empty?)
          current_section = $1
        end
        line_marker = 0
      elsif !(line =~ /-------------------------------------------------------/).nil? && line_marker == 2
        line_marker = 3
        test_section_started = true
        test_section = current_section
      elsif !(line =~ /-------------------------------------------------------/).nil? && line_marker == 3
        line_marker = 0
        test_section_started = false
      else
        line_marker = 0
      end

      if test_section_started
        @test_lines << line
      elsif reactor_started
        @reactor_lines << line
      end
    end
  end

  def analyze_reactor()
    reactor_time = 0
    @reactor_lines.each do |line|
      if !(line =~ /\[INFO\] .*test.*? (\w+) \[ (.+)\]/i).nil?
        reactor_time += convert_maven_time_to_seconds($2)
      elsif !(line =~ /Total time: (.+)/i).nil?
        @pure_build_duration = convert_maven_time_to_seconds($1)
      end
    end
    if @test_duration.nil? || reactor_time > @test_duration
      @test_duration = reactor_time
    end
  end

  def convert_maven_time_to_seconds(string)
    if !(string =~ /((\d+)(\.\d*)?) s/).nil?
      return $1.to_f.round(2)
    elsif !(string =~ /(\d+):(\d+) min/).nil?
      return $1.to_i * 60 + $2.to_i
    end
    return 0
  end

  def extractTestNameAndMethod(string)
    string.split(':')[0].split('.')[0].split('(')
  end

  def analyze_tests
    failed_tests_started = false

    @test_lines.each do |line|
      if failed_tests_started
        @tests_failed_lines << line
        if line.strip.empty?
          failed_tests_started = false
        end
      end
      if !(line =~ /Tests run: .*? Time elapsed: (.* sec)/).nil?
        init_tests
        @tests_run = true
        add_framework 'junit'
        @test_duration += convert_maven_time_to_seconds $1
      elsif !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*)(, Skipped: (\d*))?/).nil?
        init_tests
        @tests_run = true
        add_framework 'junit'
        @num_tests_run = $1.to_i
        @num_tests_failed = $2.to_i + $3.to_i
        @num_tests_skipped = $5.to_i unless $4.nil?
      elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
        init_tests
        add_framework 'testng'
        @tests_run = true
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i
        @num_tests_skipped += $3.to_i
      elsif !(line =~ /(Failed tests:)|(Tests in error:)/).nil?
        failed_tests_started = true
      end
    end
    uninit_ok_tests
  end

  def getOffendingTests
    @tests_failed_lines.each { |l| @tests_failed << extractTestNameAndMethod(l)[0].strip }
  end

  def tests_failed?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end
end