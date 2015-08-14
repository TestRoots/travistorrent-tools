load 'travis_fold.rb'

# A language-independent analyzer for travis logfiles
# Provides basic statistics about any build process on Travis.
class LogFileAnalyzer
  attr_reader :build_number, :build_id, :commit

  attr_reader :logFile
  attr_reader :status, :primary_language
  attr_reader :tests_run
  attr_reader :num_tests_run, :num_tests_failed, :num_tests_ok, :num_tests_skipped
  attr_reader :setup_time_before_build

  @folds
  @test_lines

  OUT_OF_FOLD = 'out_of_fold'

  def initialize(file)
    @folds = Hash.new
    @test_lines = Array.new

    get_build_info(file)
    logFile = File.read(file)
    logFile = logFile.encode(logFile.encoding, :universal_newline => true)
    @logFile = logFile.lines

    @tests_run = false
    @status = 'unknown'
  end

  def get_build_info(file)
    @build_number, @commit, @build_id = File.basename(file, '.log').split('_')
  end

  def anaylze_status
    unless (@folds[OUT_OF_FOLD].content.last =~/^Done: Job Cancelled/).nil?
      @status = 'cancelled'
    end
    unless (@folds[OUT_OF_FOLD].content.last =~/^Done. Your build exited with (\d*)\./).nil?
      @status = $1.to_i === 0 ? 'ok' : 'broken'
    end

  end

  def anaylze_primary_language
    @folds['system_info'].content.each do |line|
      unless (line =~/^Build language: (.*)/).nil?
        @primary_language = $1
      end
    end
  end

  def split
    currentFold = OUT_OF_FOLD
    @logFile.each do |line|
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

  def analyze
    split
    anaylze_primary_language
    anaylze_status
    analyzeSetupTimeBeforeBuild
  end

  def output
    keys = ['build_id', 'commit', 'build_number', 'lan', 'status', 'setup_time', 'tests_run?',]
    values = [@build_id, @commit, @build_number, @primary_language, @status, @setup_time_before_build, @tests_run]
    flattened_values = keys.zip(values).flat_map { |k, v| "#{k}:#{v}" }.join(',')
  end
end
