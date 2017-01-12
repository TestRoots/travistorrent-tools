# A Mixin for the analysis of Go build files. Supports GoTest

module GoLogFileAnalyzer
  attr_reader :tests_failed, :test_duration, :reactor_lines, :pure_build_duration

  def init
    @reactor_lines = Array.new
    @tests_failed_lines = Array.new
    @tests_failed = Array.new
    @analyzer = 'go'
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

  def convert_go_time_to_seconds(string)
    if !(string =~ /(.+)s/).nil?
      return $1.to_f.round(2)
    end
    return 0
  end

  def extractTestNameAndMethod(string)
    string.split(':')[0].split('.')[0].split('(')
  end

  def setup_go_tests
    init_tests
    @tests_run = true
    add_framework 'gotest'
  end

  def analyze_tests
    use_verbose_style = false

    @test_lines.each do |line|
      if !(line =~ /--- PASS/).nil?
        use_verbose_style = true
      end
    end

    puts use_verbose_style

    @test_lines.each do |line|
      puts line
      # matches the likes of: --- PASS: TestS3StorageManyFiles-2 (13.10s)
      if !(line =~ /--- PASS: (.+)? (\((.+)\))?/).nil? && use_verbose_style
        setup_go_tests
        @num_tests_run += 1
        @test_duration += convert_go_time_to_seconds $3
      elsif !(line =~ /ok\s((\S+)\S(\S+)?)?/).nil? && !use_verbose_style
        # matches the likes of: ok  	github.com/dghubble/gologin	0.004s
        setup_go_tests
        @num_tests_run += 1
        @test_duration += convert_go_time_to_seconds $3
      elsif !(line =~ /--- SKIP: /).nil?
        setup_go_tests
        @num_tests_skipped += 1
      elsif !(line =~ /FAIL\s(\S+)?(\s(.+))?/).nil?
        setup_go_tests
        @num_tests_failed += 1
        @test_duration += convert_go_time_to_seconds $3
        @tests_failed.push($1) unless $1.nil?
      end
    end

    uninit_ok_tests
  end

  def tests_failed?
    return !@tests_failed.empty? || (!@num_tests_failed.nil? && @num_tests_failed > 0)
  end

end
