load '../travis_fold.rb'

class JavaLogFileAnalyzer < LogFileAnalyzer

  def initialize
    super('logs/java-log.txt')
  end

  def analyze
    test_section_started = false
    test_marker = false
    test_lines = Array.new

    @folds[OUT_OF_FOLD].content.each do |line|
      if !(line =~ /-------------------------------------------------------/).nil? && test_marker
        test_section_started = true
      elsif !(line =~ /T E S T S/).nil?
        test_marker = true
      end

      if test_section_started
        test_lines << line
        if !(line =~ /[INFO] ------------------------------------------------------------------------/).nil?
          test_section_started = false
        end
      end
    end

    puts @folds[OUT_OF_FOLD].duration
  end
end