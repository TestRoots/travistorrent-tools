require 'colorize'

load 'lib/travis_fold.rb'


# Provides general language-independent analyzer for Travis logfiles. Dynamically mixes-in the most specific language
# analyzer from the languages packages. If no specific analyzer is found, it prrovides basic statistics about any build
# process on Travis.

class LogFileAnalyzer
  attr_reader :build_id, :job_id, :commit

  attr_reader :logFile
  attr_reader :status, :primary_language
  attr_reader :tests_run
  attr_reader :num_tests_run, :num_tests_failed, :num_tests_ok, :num_tests_skipped
  attr_reader :test_duration
  attr_reader :setup_time_before_build

  @folds
  @test_lines
  @analyzer
  @frameworks

  @OUT_OF_FOLD

  def initialize(file)
    @OUT_OF_FOLD = 'out_of_fold'
    @folds = Hash.new
    @test_lines = Array.new
    @frameworks = Array.new

    get_build_info(file)
    @logFile = File.read(file)
    encoding_options = {
        :invalid => :replace, # Replace invalid byte sequences
        :undef => :replace, # Replace anything not defined in ASCII
        :replace => '', # Use a blank for those replacements
        :universal_newline => true # Always break lines with \n
    }
    @logFile = @logFile.encode(Encoding.find('ASCII'), encoding_options)
    @logFileLines = @logFile.lines

    @primary_language = 'unknown'
    @analyzer = 'plain'
    @tests_run = false
    @tests_failed = Array.new
    @status = 'unknown'
    @did_tests_fail = ''
  end

  def mixin_specific_language_analyzer
    split
    analyze_primary_language
    lang = primary_language.downcase

    # Dynamically add mixins
    if lang == 'ruby'
      self.extend(RubyLogFileAnalyzer)
    elsif lang == 'java'
      self.extend(JavaLogFileAnalyzerDispatcher)
    end
  end

  # Template method pattern. Sub classes implement their own analyses in custom_analyze
  def analyze
    anaylze_status
    analyzeSetupTimeBeforeBuild
    custom_analyze
    pre_output
    sanitize_output
  end

  # Intentionally left empty. Mixins should define this method for their customized build process
  def custom_analyze
  end

  # Intentionally left empty. Mixins should define their initialization in this method.
  def init
  end

  def get_build_info(file)
    @build_id, @commit, @job_id = File.basename(file, '.log').split('_')
  end

  # Analyze the buildlog exit status
  def anaylze_status
    unless (@folds[@OUT_OF_FOLD].content.last =~/^Done: Job Cancelled/).nil?
      @status = 'cancelled'
    end
    unless (@folds[@OUT_OF_FOLD].content.last =~/^Done. Your build exited with (\d*)\./).nil?
      @status = $1.to_i === 0 ? 'ok' : 'broken'
    end

  end

  # Analyze what the primary language of this build is
  def analyze_primary_language
    system_info = 'system_info'
    if !@folds[system_info].nil?
      @folds[system_info].content.each do |line|
        unless (line =~/^Build language: (.*)/).nil?
          @primary_language = $1
          return
        end
      end
    else
      # in case folding does not work, make educated guess at language
      if @logFile.scan(/java/m).size >= 3
        @primary_language = 'java'
      elsif @logFile.scan(/ruby/m).size >= 3
        @primary_language = 'ruby'
      end
    end
  end

  # Split buildlog into different Folds
  def split
    currentFold = @OUT_OF_FOLD
    @logFileLines.each do |line|
      line = line.uncolorize

      if !(line =~ /travis_fold:start:([\w\.]*)/).nil?
        currentFold = $1
        next
      end

      if !(line =~ /travis_fold:end:([\w\.]*)/).nil?
        currentFold = @OUT_OF_FOLD
        next
      end

      if @folds[currentFold].nil?
        @folds[currentFold] = TravisFold.new(currentFold)
      end

      if !(line =~ /travis_time:.*?,duration=(\d*)/).nil?
        @folds[currentFold].duration = ($1.to_f/1000/1000/1000).round # to convert to seconds
        next
      end

      @folds[currentFold].content << line
    end
  end

  def analyzeSetupTimeBeforeBuild
    @folds.each do |foldname, fold|
      if !(fold.fold =~ /(system_info|git.checkout|services|before.install)/).nil?
        @setup_time_before_build = 0 if @setup_time_before_build.nil?
        @setup_time_before_build += fold.duration if !fold.duration.nil?
      end
    end
  end

  def add_framework framework
    @frameworks << framework unless @frameworks.include? framework
  end

  # pre-init values so we can sum-up in case of aggregated test sessions (always use calc_ok_tests when you use this)
  def init_tests
    unless @init_tests
      @test_duration = 0
      @num_tests_run = 0
      @num_tests_failed = 0
      @num_tests_ok = 0
      @num_tests_skipped = 0
      @init_tests = true
    end
  end

  # For non-aggregated reporting, at the end (always use this when you use init_tests)
  def uninit_ok_tests
    if (!@num_tests_run.nil? && !@num_tests_failed.nil?)
      @num_tests_ok += @num_tests_run - @num_tests_failed
    end
  end

  def tests_failed?
    return ''
  end

  # Returns a HashMap of results from the analysis
  def output
    keys = ['tr_build_id', 'commit', 'tr_job_id', 'tr_lan', 'tr_status', 'tr_setup_time',
            'tr_analyzer', 'tr_frameworks',
            'tr_tests_ran', 'tr_tests_failed', 'tr_tests_ok', 'tr_tests_fail', 'tr_tests_run', 'tr_tests_skipped',
            'tr_failed_tests', 'tr_testduration', 'tr_purebuildduration']
    values = [@build_id, @commit, @job_id, @primary_language, @status, @setup_time_before_build,
              @analyzer, @frameworks.join('#'),
              @tests_run, @did_tests_fail, @num_tests_ok, @num_tests_failed, @num_tests_run,
              @num_tests_skipped, @tests_failed.join('#'), @test_duration,
              @pure_build_duration]
    Hash[keys.zip values]
  end

  # Assign function values to variables before outputting
  def pre_output
    @did_tests_fail = tests_failed?
  end

  # Perform last-second sanitaztion of variables. Can be used to guarantee invariants.
  # TODO (MMB) Implement some of the R checks here?
  def sanitize_output
    @did_tests_fail = '' if !@tests_run
  end

end
