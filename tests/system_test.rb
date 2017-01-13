require "minitest/autorun"
require "buildlog_analyzer_dispatcher"

# System tests for Travis build analysis

class SystemTest < MiniTest::Test

  make_my_diffs_pretty!

  def prepare_file(file)
    csv = JSON.pretty_generate File.open(file).readlines
    csv
  end

  def make_comparison(dir)
    dispatcher = BuildlogAnalyzerDispatcher.new(dir, false)
    dispatcher.start

    expected_data = prepare_file "#{dir}/#{dispatcher.result_file_name}.json-expected"
    actual_data = prepare_file "#{dir}/#{dispatcher.result_file_name}.json"

    assert_equal expected_data, actual_data, "Difference on #{dir} buildlogs!"
  end

  def test_ant
    make_comparison("dev_logs/ant@ant")
  end

  def test_watchdog
    make_comparison("dev_logs/TestRoots@watchdog")
  end

  def test_cucumber
    make_comparison("dev_logs/cucumber@cucumber")
  end

  def test_mockito
    make_comparison("dev_logs/mockito@mockito")
  end

  def test_rails
    make_comparison("dev_logs/rails@rails")
  end

  def test_connectbot
    make_comparison("dev_logs/connectbot@connectbot")
  end

  def test_bbcnews
    make_comparison("dev_logs/BBC-News@wraith")
  end

  def test_go
    make_comparison("dev_logs/facebookgo@rocks-strata")
  end
end