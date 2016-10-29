require "minitest/autorun"
require "buildlog_analyzer_dispatcher"


class TestMeme < Minitest::Test
  def make_comparison(dir)
    dispatcher = BuildlogAnalyzerDispatcher.new(dir, false)
    dispatcher.start
    assert FileUtils.identical?("#{dir}/#{dispatcher.result_file_name}", "#{dir}/expected-#{dispatcher.result_file_name}"), "Difference on #{dir} buildlogs!"
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

  def mockito
    make_comparison("dev_logs/mockito@mockito")
  end

  def rails
    make_comparison("dev_logs/rails@rails")
  end

end