load 'travis_fold.rb'

class LogFileAnalyzer
  attr_reader :logFile
  attr_reader :status, :primary_language
  attr_reader :num_tests_run, :num_tests_failed, :num_tests_ok, :num_tests_skipped

  @folds
  @test_lines

  OUT_OF_FOLD = 'out_of_fold'

  def initialize(file)
    @folds = Hash.new
    @test_lines = Array.new
    puts "reading file #{file}"
    logFile = File.read(file)
    logFile = logFile.encode(logFile.encoding, :universal_newline => true)
    @logFile = logFile.lines

    @num_tests_run = 0
    @num_tests_failed = 0
    @num_tests_ok = 0
    @num_tests_skipped = 0
  end

  def anaylze_status
    @folds[OUT_OF_FOLD].content.last =~/^Done. Your build exited with (\d*)\./
    @status = ($1 === 0 ? "ok" : "broken")
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
        @folds[currentFold].duration = $1.to_i #/1000/1000/1000  to convert to seconds
        next
      end

      @folds[currentFold].content << line
    end
  end
end

# todo: add Done: Job Cancelled