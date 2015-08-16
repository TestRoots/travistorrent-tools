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
      elsif !(line =~ /rspec/).nil?
        line_marker = 2 # rspec tests do not stop
        test_section_started = true
        @tests_run = true
      elsif !(line =~ /\A:(\w*)/).nil? && line_marker == 1
        line_marker = 0
        test_section_started = false
      elsif !(line =~ /\A:(\d) scenarios?/).nil?
        line_marker = 2 # cucumber tests do not stop
        test_section_started = true
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
    failed_unit_tests_started = false
    failed_rspec_tests_started = false
    cucumber_failing_tests_started = false
    expect_cucumber_time = false

    @test_lines.each do |line|
      # MiniTest and TestUnit
      if !(line =~ /(\d+) runs?, (\d+) assertions, (\d+) failures, (\d+) errors(, (\d+) skips)?/).nil?
        init_tests
        @tests_run = true
        add_framework 'testunit'
        @num_tests_run += $1.to_i
        @num_tests_failed += $3.to_i + $4.to_i
        @num_tests_skipped += $6.to_i if !$6.nil?
      elsif !(line =~ / Failure:/).nil?
        failed_unit_tests_started = true
      elsif failed_unit_tests_started
        @tests_failed << extractTestNameAndMethod(line)[0]
        failed_unit_tests_started = false
      end

      # shared between TestUnit and RSpec
      if !(line =~ /Finished in (.*)/).nil?
        init_tests
        @test_duration += convert_time_to_seconds($1)
      end

      # RSpec
      if !(line =~ /(\d+) examples?, (\d+) failures?(, (\d+) pending)?/).nil?
        init_tests
        @tests_run = true
        add_framework 'rspec'
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i
        @num_tests_skipped += $4.to_i
      elsif !(line =~ /Failed examples:/).nil?
        failed_rspec_tests_started = true
      elsif failed_rspec_tests_started
        if (line =~ /rspec (.*\.rb):\d+/).nil?
          failed_rspec_tests_started = false
        else
          @tests_failed << $1
        end
      end

      # RSpec
      if !(line =~ /(\d+) examples?, (\d+) failures?(, (\d+) pending)?/).nil?
        init_tests
        @tests_run = true
        add_framework 'rspec'
        @num_tests_run += $1.to_i
        @num_tests_failed += $2.to_i
        @num_tests_skipped += $4.to_i
      elsif !(line =~ /Failed examples:/).nil?
        failed_rspec_tests_started = true
      elsif failed_rspec_tests_started
        if (line =~ /rspec (.*\.rb):\d+/).nil?
          failed_rspec_tests_started = false
        else
          @tests_failed << $1
        end
      end

      # cucumber
      if !(line =~ /(\d+) scenarios?/).nil?
        init_tests
        @tests_run = true
        add_framework 'cucumber'
        @num_tests_run += $1.to_i
        puts line
        if !(line =~ /\d+ scenarios? \(.*?(\d+) failed, (\d+) passed\)/).nil?
          puts 'fuck'
          @num_tests_failed += $1.to_i
        end
      elsif !(line =~ /Failing Scenarios:/).nil?
        cucumber_failing_tests_started = true
      elsif (cucumber_failing_tests_started)
        if !(line =~ /cucumber (.*?):(\d*)/).nil?
          init_tests
          @tests_failed << $1
        else
          cucumber_failing_tests_started = false
        end
      elsif !(line =~ /\d steps?/).nil?
        expect_cucumber_time = true
      elsif expect_cucumber_time
        @test_duration += convert_time_to_seconds line
        expect_cucumber_time = false
      end
    end

    uninit_ok_tests
  end
end

def convert_time_to_seconds(string)
  if !(string =~ /((\d+)m)?(\d+\.\d*)( )?s/).nil?
    return $2.to_f * 60 + $3.to_f.round(2)
  end
end

def getOffendingTests
  @tests_failed_lines.each { |l| @tests_failed << extractTestNameAndMethod(l)[0] }
end

def tests_failed?
  return @num_tests_failed > 0 || !@tests_failed.empty? || @test_failed
end
