# A Mixin for the analysis of Python build files. Supports unittest, tox, pytest (WIP)

module PythonLogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  def init
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'python'
    @verbose = false
    @has_summary = false
  end

  def custom_analyze
    extract_tests
    analyze_tests
  end

  def extract_tests
    test_section_started = false

    # TODO (MMB) Possible future improvement: We could even get all executed tests (also the ones which succeed)
    # DO something similar for, e.g., the tox framework?
    @folds[@OUT_OF_FOLD].content.each do |line|
      if !(line =~ /Ran .* tests? in /).nil?
        @has_summary = true
      end
    end

    if @test_lines.empty?
      @test_lines = @folds[@OUT_OF_FOLD].content
    end
  end

  def setup_python_tests
    unless @init_tests
      init_tests
      @tests_run = true
      @force_tests_passed = false
      @force_tests_failed = false
    end
  end

  def analyze_pytest_status_info_list(string)
    additional_information = string.split(', ')
    additional_information.each do |arg|
      arg.split(' ').each_cons(2) do |val, key|
        # TODO: we could add xpassed syntax here
        case key.downcase
          when 'passed'
            @num_tests_run += val.to_i
          when 'failed'
            @num_tests_failed += val.to_i
            @num_tests_runt += val.to_i
        end
      end
    end
  end

  def analyze_status_info_list(string)
    additional_information = string.split(', ')
    additional_information.each do |arg|
      arg.split('=').each_cons(2) do |key, val|
        # TODO: we could add xpassed syntax here
        case key.downcase
        when 'skip'
            @num_tests_skipped = val.to_i
          when 'errors', 'failures', 'error', 'failure'
            @num_tests_failed += val.to_i
        end
      end
    end
  end

  def analyze_tests
    summary_seen = false

    @test_lines.each do |line|
      if !(line =~ /Ran (\d+) tests? in (.+s)/).nil?
        # Matches the testunit test summary, i.e. "Ran 3 tests in 0.000s"
        setup_python_tests
        add_framework 'unittest'
        @num_tests_run = $1.to_i
        @test_duration += convert_plain_time_to_seconds $2
        @has_summary = true
      elsif !(line =~ /==================== (.+) in (.+) seconds ====================/).nil?
        # Matches the pytest test summary, i.e. "==================== 442 passed, 2 xpassed in 50.65 seconds ===================="
        # TODO: pytest: missing fail detection
        setup_python_tests
        add_framework 'pytest'
        analyze_pytest_status_info_list $1
        @test_duration += $2.to_f
      elsif !(line =~ /^OK( \((.+)\))?\s*$/).nil? and @has_summary
        # This is a somewhat dangerous thing to do as "OK" might be a common line in builds. We mititgate the risk somewhat by having seen a summary
        # TODO we can make this more clever by checking only AFTER a summary
        setup_python_tests
        # If we see this, we know that the overall result was that tests passed
        @force_tests_passed = true
        analyze_status_info_list $2
        summary_seen = true
      elsif !(line =~ /^FAILED( \((.+)\))?\s*$/).nil? and @has_summary
        # This is a somewhat dangerous thing to do as "OK" might be a common line in builds. We mititgate the risk somewhat by having seen a summary
        # TODO we can make this more clever by checking only AFTER a summary
        setup_python_tests
        # If we see this, we know that the overall result was that tests failed
        @force_tests_passed = false
        @force_tests_failed = true
        analyze_status_info_list $2
        summary_seen = true
      elsif !(line =~ /^((FAIL)|(ERROR)): ([^(]+)$/).nil? and !summary_seen
        # TODO: clear stuff ala "py27: commands failed" from it
        # Matches the likes of FAIL: test_em (__main__.TestMarkdownPy)
        setup_python_tests
        add_failed_test $4
      elsif !(line =~ /^FAIL: (\S+)/).nil? and !summary_seen
        # Matches the likes of FAIL: test_em (__main__.TestMarkdownPy)
        setup_python_tests
        add_failed_test $1
      end
    end

    uninit_ok_tests
  end

  def tests_failed?
    return false if @force_tests_passed
    return true if @force_tests_failed

    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end
