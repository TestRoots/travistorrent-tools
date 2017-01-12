# A Mixin for the analysis of Go build files. Supports GoTest

module GoLogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  @test_failed_lines

  def init_deep
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'go'
  end

  def custom_analyze
    extract_tests
    analyze_tests

    getOffendingTests
  end

  def extract_tests
    test_section_started = false

    # TODO (MMB) Possible future improvement: We could even get all executed tests (also the ones which succeed)
    @folds[@OUT_OF_FOLD].content.each do |line|

      if !(line =~ / go test/).nil?
        test_section_started = true
      elsif !(line =~ /The command "go test/).nil? && test_section_started
        test_section_started = false
      end

      if test_section_started
        @test_lines << line
      end
    end
  end

  def convert_go_time_to_seconds(string)
    if !(string =~ /(.+)s/).nil?
      return $1.to_f.round(2)
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
      # matches the likes of: --- PASS: TestS3StorageManyFiles-2 (13.10s)
      if !(line =~ /--- PASS: (.+)? (\((.+)\))?/).nil?
        init_tests
        @tests_run = true
        add_framework 'gotest'
        @num_tests_run += 1
        @test_duration += convert_go_time_to_seconds $3
      elsif !(line =~ /--- SKIP: /).nil?
        init_tests
        @tests_run = true
        add_framework 'gotest'
        @num_tests_skipped += 1
      end
    end

    uninit_ok_tests
  end

  def getOffendingTests
    #@tests_failed_lines.each { |l| @tests_failed << extractTestNameAndMethod(l)[0].strip }
  end

  def tests_failed?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end
