# A Mixin for the analysis of Go build files. Supports GoTest and GoConvey, which uses GoTest's output

module GoLogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  def init
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'go'
    @verbose = false
  end

  def custom_analyze
    extract_tests
    analyze_tests
  end

  def extract_tests
    test_section_started = false

    # TODO (MMB) Possible future improvement: We could even get all executed tests (also the ones which succeed)
    @folds[@OUT_OF_FOLD].content.each do |line|

      if !(line =~ /go test/).nil?
        test_section_started = true
        if !(line =~ /-v/).nil?
          @verbose = true
        end
      elsif !(line =~ /The command "go test/).nil? && test_section_started
        test_section_started = false
      end

      if test_section_started
        @test_lines << line
      end
    end

    if @test_lines.empty?
      @test_lines = @folds[@OUT_OF_FOLD].content
    end
  end

  def setup_go_tests
    unless @init_tests
      init_tests
      @tests_run = true

      @num_test_suites_failed = 0
      @num_test_suites_run = 0
      @num_test_suites_ok = 0

      add_framework 'gotest'
    end
  end

  def analyze_tests

    @test_lines.each do |line|
      if !(line =~ /--- PASS/).nil?
        @verbose = true
      end
    end

    @test_lines.each do |line|
      # matches the likes of: --- PASS: TestS3StorageManyFiles-2 (13.10s)
      if !(line =~ /--- PASS: (.+)? (\((.+)\))?/).nil?
        setup_go_tests
        @num_tests_run += 1
        @verbose = true
        @test_duration += convert_plain_time_to_seconds $3 if @verbose
      elsif !(line =~ /ok\s+(\S+\s+(\S+))?/).nil?
        # matches the likes of: ok  	github.com/dghubble/gologin	0.004s
        setup_go_tests
        @num_test_suites_run += 1
        @test_duration += convert_plain_time_to_seconds $2 unless @verbose
      elsif !(line =~ /--- SKIP: /).nil?
        setup_go_tests
        @num_tests_skipped += 1
      elsif !(line =~ /--- FAIL: (.+)? (\((.+)\))?/).nil?
        setup_go_tests
        @num_tests_run += 1
        @num_tests_failed += 1
        @tests_failed.push($1) unless $1.nil?
        @num_test_suites_failed += 1
        @test_duration += convert_plain_time_to_seconds $3
      elsif !(line =~ /FAIL\s+(\S+)(\s(.+))?/).nil?
        setup_go_tests
        @num_tests_run += 1
        @num_tests_failed += 1
        @tests_failed.push($1) unless $1.nil?
        @test_duration += convert_plain_time_to_seconds $3
      end
    end

    # In case we are not verbose, we do not know the number of test cases run. Tough luck
    @num_tests_run = nil unless @verbose

    if (!@num_test_suites_run.nil? && !@num_test_suites_failed.nil?)
      @num_test_suites_ok = @num_test_suites_run - @num_test_suites_failed
    end

    uninit_ok_tests
  end

  def tests_failed?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end
