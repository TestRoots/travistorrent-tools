require 'colorize'

load 'lib/travis_fold.rb'


# A language-independent analyzer for travis logfiles
# Provides basic statistics about any build process on Travis.
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

  OUT_OF_FOLD = 'out_of_fold'

  def initialize(file)
    @folds = Hash.new
    @test_lines = Array.new
    @frameworks = Array.new

    get_build_info(file)
    logFile = File.read(file)
    encoding_options = {
        :invalid => :replace, # Replace invalid byte sequences
        :undef => :replace, # Replace anything not defined in ASCII
        :replace => '', # Use a blank for those replacements
        # fix for ruby version > 2.0, otherwise uncomment on ruby 1.9
        #:UNIVERSAL_NEWLINE_DECORATOR => true
        :universal_newline => true # Always break lines with \n
    }
    @logFile = logFile.encode(Encoding.find('ASCII'), encoding_options)
    @logFileLines = @logFile.lines

    @primary_language = 'unknwon'
    @analyzer = 'plain'
    @tests_run = false
    @status = 'unknown'
  end

  def get_build_info(file)
    @build_id, @commit, @job_id = File.basename(file, '.log').split('_')
  end

  def anaylze_status
    unless (@folds[OUT_OF_FOLD].content.last =~/^Done: Job Cancelled/).nil?
      @status = 'cancelled'
    end
    unless (@folds[OUT_OF_FOLD].content.last =~/^Done. Your build exited with (\d*)\./).nil?
      @status = $1.to_i === 0 ? 'ok' : 'broken'
    end

  end

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

  def split
    currentFold = OUT_OF_FOLD
    @logFileLines.each do |line|
      line = line.uncolorize

      if !(line =~ /travis_fold:start:([\w\.]*)/).nil?
        currentFold = $1
        next
      end

      if !(line =~ /travis_fold:end:([\w\.]*)/).nil?
        currentFold = OUT_OF_FOLD
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

  def output
    keys = ['build_number', 'commit', 'job_id', 'lan', 'status', 'setup_time',
            'analyzer', 'frameworks',
            'tests_run?', 'tests_failed?', 'ok', 'failed', 'run', 'skipped', 'failed_tests', 'testduration',
            'purebuildduration']
    values = [@build_id, @commit, @job_id, @primary_language, @status, @setup_time_before_build,
              @analyzer, @frameworks.join('#'),
              @tests_run, tests_failed?, @num_tests_ok, @num_tests_failed, @num_tests_run,
              @num_tests_skipped, @tests_failed.join('#'), @test_duration,
              @pure_build_duration]
    Hash[keys.zip values]
  end


  def analyze
    split
    analyze_primary_language
    anaylze_status
    analyzeSetupTimeBeforeBuild
  end
end
