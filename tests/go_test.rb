require 'minitest/autorun'
require 'ghtorrent_extractor/go'

describe GoData do

  describe 'when asked to filter paths' do

    test_file_filter = Class.new.extend(GoData).test_file_filter
    it 'must accept Go test paths' do
      assert test_file_filter.call('/foo/bar/unit_test_unit_test.go')
    end

    it 'must reject non-Go test paths' do
      assert (not test_file_filter.call('/foo/bar/unit_test_unit.go.back'))
      assert (not test_file_filter.call('/foo/bar/unit_test_unit.go'))
      assert (not test_file_filter.call('/foo/tests/foo.go'))
    end

  end

  describe 'when asked to filter src files' do

    src_file_filter = Class.new.extend(GoData).src_file_filter
    it 'must accept Go src paths' do
      assert src_file_filter.call('/foo/bar.go')
    end

    it 'must reject non-Go src paths' do
      assert (not src_file_filter.call('/foo/bar/unit_test.java'))
      assert (not src_file_filter.call('/foo/bar/unit_test.golang'))
      assert (not src_file_filter.call('/foo/bar/unit_test.go'))
    end

  end

  describe 'when asked to recognize test cases' do

    test_case_filter = Class.new.extend(GoData).test_case_filter

    it 'must accept valid test function names' do
      assert test_case_filter.call('func TestXxx(*testing.T)')
      assert test_case_filter.call('func  TestXxx(*testing.T)')
      assert test_case_filter.call('func TestXxx( *testing.T)')
      assert test_case_filter.call('func TestXxx(*testing.T )')
      assert test_case_filter.call('func TestΤεστ(*testing.T )')
      assert test_case_filter.call('func TestΤεστ (*testing.T )')
      assert test_case_filter.call('func Testτεστ(*testing.T)')

    end

    it 'must reject invalid test function names' do
      assert (not test_case_filter.call('func Test(*testing.T)'))
      assert (not test_case_filter.call('func ΤestFoo(*testing.T)'))
      assert (not test_case_filter.call('func testFoo(*testing.T)'))
      assert (not test_case_filter.call("func testFoo(*testing.T\n)"))
    end

  end


end