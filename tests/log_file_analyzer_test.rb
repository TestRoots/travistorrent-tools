require 'minitest/autorun'
require 'log_file_analyzer'

describe LogFileAnalyzer do

  describe 'when a build timesout' do
    analyzer = LogFileAnalyzer.new 'dev_logs/generics/maximum_time_aborted_192852537.log'
    analyzer.mixin_specific_language_analyzer
    analyzer.init
    analyzer.analyze
    results = analyzer.output
    it 'must have timeout as the status' do
      results[:tr_log_status].must_equal "timeout"
    end

  end

end