require 'minitest/autorun'
require 'ghtorrent_extractor/python'


describe PythonData do

  describe 'when asked to filter paths' do

    test_file_filter = Class.new.extend(PythonData).test_file_filter
    it 'must accept Python test paths' do
      assert test_file_filter.call('/foo/bar/foo_test.py')
      assert test_file_filter.call('/foo/bar/test_foo.py')
      assert test_file_filter.call('/foo/tests/foo.py')
      assert test_file_filter.call('/foo/test/test_foo.py')
    end

    it 'must reject non-python test paths' do
      assert (not test_file_filter.call('/foo/bar/foo_test.pyc'))
      assert (not test_file_filter.call('/foo/bar/test_foo.java'))
      assert (not test_file_filter.call('/foo/test/test_foo.java'))
    end

  end

  describe 'when asked to filter src files' do

    src_file_filter = Class.new.extend(PythonData).src_file_filter
    it 'must accept Python src paths' do
      assert src_file_filter.call('/foo/bar.py')
      assert src_file_filter.call('bar_.py')
    end

    it 'must reject non-Python src paths' do
      assert (not src_file_filter.call('/foo/bar/unit_test.pyc'))
      assert (not src_file_filter.call('/foo/bar/unit_test.go'))
      assert (not src_file_filter.call('/foo/tests/unit_test.py'))
    end

  end

  describe 'when asked to recognize test cases' do

    it 'must accept valid test function names' do
      assert Class.new.extend(PythonData).test_case_filter.call('def test_foo():')
      assert Class.new.extend(PythonData).test_case_filter.call('def test_foo(self, kwargs *):')
    end

    it 'must reject valid test function names' do
      assert (not Class.new.extend(PythonData).test_case_filter.call('def foo_test():'))
    end

  end

  describe 'when asked to recognize assertions' do

    it 'must accept valid pytest assertions' do
      assert Class.new.extend(PythonData).pytest_assertion?('with raises(ValueError) as exc_info:')
      assert Class.new.extend(PythonData).pytest_assertion?('with pytest.raises(ValueError) as exc_info:')
      assert Class.new.extend(PythonData).pytest_assertion?('pytest.raises(ValueError)')

      assert Class.new.extend(PythonData).pytest_assertion?('(0.1 + 0.2, 0.2 + 0.4) == approx((0.3, 0.6))')
      assert Class.new.extend(PythonData).pytest_assertion?('(0.1 + 0.2, 0.2 + 0.4) == pytest.approx((0.3, 0.6))')
    end

    it 'must accept valid assertions' do
      assert Class.new.extend(PythonData).assertion_filter.call('assert self._id2name_map[id] == name')
      assert Class.new.extend(PythonData).assertion_filter.call('assertFailure self._id2name_map[id] == name')
      assert Class.new.extend(PythonData).pytest_assertion?('with pytest.raises(ValueError) as exc_info:')
    end

  end

end