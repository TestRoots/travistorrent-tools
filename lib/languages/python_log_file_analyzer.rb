# A Mixin for the analysis of Python build files. Supports unittest, tox

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
    end
  end

  def analyze_tests
    @test_lines.each do |line|
      if !(line =~ /Ran (\d+) tests? in (.+s)/).nil?
        # Matches the test summary, i.e. "Ran 3 tests in 0.000s"
        setup_python_tests
        add_framework 'unittest'
        @num_tests_run = $1.to_i
        @test_duration += convert_plain_time_to_seconds $2
        @has_summary = true
      elsif !(line =~ /^OK( \((.+)\))?\s*$/).nil? and @has_summary
        # This is a somewhat dangerous thing to do as "OK" might be a common line in builds. We mititgate the risk somewhat by having seen a summary
        # TODO we can make this more clever by checking only AFTER a summary
        setup_python_tests
        # If we see this, we know that the overall result was that tests passed
        @force_tests_passed = true
        additional_information = $2.split(', ')
        additional_information.each do |arg|
          arg.split('=').each_cons(2) do |key, val|
            # TODO: we could add xpassed syntax here
            case key.downcase
              when 'skip'
                @num_tests_skipped = val.to_i
            end
          end
        end

        #.split('=') do |key, val|
        # puts key, val
        #end
      elsif !(line =~ /FAIL: (\S+)/).nil?
        # Matches the likes of FAIL: test_em (__main__.TestMarkdownPy)
        setup_python_tests
        @tests_failed.push($1) unless $1.nil?
      end
    end

    uninit_ok_tests
  end

  def tests_failed?
    return !@force_tests_passed || !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end
