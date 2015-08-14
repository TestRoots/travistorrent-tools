# Supports any test execution with Maven
class JavaAntLogFileAnalyzer < LogFileAnalyzer
  attr_reader :tests_failed, :pure_build_duration

  @test_failed_lines

  def initialize(file)
    super(file)
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'java-ant'
  end

  def analyze
    super

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
    @folds[OUT_OF_FOLD].content.each do |line|
      if !(line =~ /\[junit\] /).nil?
        test_section_started = true
      elsif !(line =~ /Total time: (.+)/i).nil?
        @pure_build_duration = convert_ant_time_to_seconds($1)
      else
        test_section_started = false
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
  end

  def extractTestNameAndMethod(string)
    string.split(':')[0].split('.').map { |t| t.split }
  end

  def analyze_tests
    failed_tests_started = false

    @test_lines.each do |line|
      puts line
      if failed_tests_started
        @tests_failed_lines << line
        if line.strip.empty?
          failed_tests_started = false
        end
      end

      if !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*), Time elapsed: (.*)/).nil?
        init_tests
        @tests_run = true
        @num_tests_run = $1.to_i
        @num_tests_failed = $2.to_i + $3.to_i
        @test_duration = convert_ant_time_to_seconds($4)
      elsif !(line =~ /Failed tests:/).nil?
        failed_tests_started = true
      end
    end
    uninit_ok_tests
  end

  def getOffendingTests
    @tests_failed_lines.each { |l| @tests_failed << extractTestNameAndMethod(l)[0] }
  end

  def tests_broke_build?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end