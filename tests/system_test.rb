require "minitest/autorun"
require "buildlog_analyzer_dispatcher"

class SystemTest < Minitest::Test

  def make_comparison(dir)
    dispatcher = BuildlogAnalyzerDispatcher.new(dir, false)
    dispatcher.start
    expected_csv = File.open("#{dir}/expected-#{dispatcher.result_file_name}").read
    actual_csv = File.open("#{dir}/#{dispatcher.result_file_name}").read
    assert_equal expected_csv, actual_csv, "Difference on #{dir} buildlogs!"
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
end