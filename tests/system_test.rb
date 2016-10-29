require "minitest/autorun"
require "buildlog_analyzer_dispatcher"

# System tests for Travis build analysis

class SystemTest < Minitest::Test

  make_my_diffs_pretty!

  def prepare_file(file)
    csv = File.open(file).readlines
    header = csv.slice!(0)
    csv.sort!
    csv.insert(0, header)
    csv
  end

  def make_comparison(dir)
    dispatcher = BuildlogAnalyzerDispatcher.new(dir, false)
    dispatcher.start

    expected_csv = prepare_file "#{dir}/expected-#{dispatcher.result_file_name}"
    actual_csv = prepare_file "#{dir}/#{dispatcher.result_file_name}"

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