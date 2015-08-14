# Supports TestUnit and RSPEC
class RubyLogFileAnalyzer < LogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  @test_failed_lines

  @test_failed

  def initialize(file)
    super(file)
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @num_tests_failed = 0

    @test_failed = false
    @analyzer = 'ruby'
  end

  def analyze
    super

    extract_tests
    analyze_tests
    getOffendingTests
  end

  def print_tests_failed
    tests_failed.join(';')
  end

  def extract_tests
    test_section_started = false
    line_marker = 0
    current_section = ''

    @folds[OUT_OF_FOLD].content.each do |line|
      if !(line =~ /\A# Running:/).nil?
        line_marker = 1
        test_section_started = true
        @tests_run = true
      elsif !(line =~ /\A:(\w*)/).nil? && line_marker == 1
        line_marker = 0
        test_section_started = false
      end

      if test_section_started
        @test_lines << line
      end
    end
  end

  def extractTestNameAndMethod(string)
    string.split(' ')[0].split('#').map { |t| t.split }
  end

  def analyze_tests
    failed_tests_started = false


    @test_lines.each do |line|
      # TestUnit
      if !(line =~ /(\d+) runs?, (\d+) assertions, (\d+) failures, (\d+) errors(, (\d+) skips)?/).nil?
        init_tests
        @tests_run = true
        @num_tests_run += $1.to_i
        @num_tests_failed += $3.to_i + $4.to_i
        @num_tests_skipped += $6.to_i if !$6.nil?
      elsif !(line =~ /Finished in (.*)/).nil?
        init_tests
        @test_duration += convert_testunit_time_to_seconds($1)
      elsif !(line =~ / Failure:/).nil?
        failed_tests_started = true
      elsif failed_tests_started
        @tests_failed << extractTestNameAndMethod(line)[0]
        failed_tests_started = false
      end

      # RSPEC
      if !(line =~ /(\d+) examples?, (\d+) failures?(, (\d+) pending)?/).nil?
        init_tests
        @tests_run = true
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i
        @num_tests_ok += @num_tests_run - @num_tests_failed
        @num_tests_skipped += $4.to_i
      end
    end

    uninit_ok_tests
  end
end

def convert_testunit_time_to_seconds(string)
  if !(string =~ /(\d+\.\d*)( )?s/).nil?
    return $1.to_f.round(2)
  end
end

def getOffendingTests
  @tests_failed_lines.each { |l| @tests_failed << extractTestNameAndMethod(l)[0] }
end

def tests_broke_build?
  return @num_tests_failed > 0 || !@tests_failed.empty? || @test_failed
end
