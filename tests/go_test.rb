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

  describe 'when asked to recognize cases' do

    it 'must accept valid test gotest function names' do
      assert Class.new.extend(GoData).is_gotest_test_case('func TestXxx(*testing.T)')
      assert Class.new.extend(GoData).is_gotest_test_case('func  TestXxx(*testing.T)')
      assert Class.new.extend(GoData).is_gotest_test_case('func TestXxx( *testing.T)')
      assert Class.new.extend(GoData).is_gotest_test_case('func TestXxx(*testing.T )')
      assert Class.new.extend(GoData).is_gotest_test_case('func TestΤεστ(*testing.T )')
      assert Class.new.extend(GoData).is_gotest_test_case('func Test_Τεστ(*testing.T )')
      assert Class.new.extend(GoData).is_gotest_test_case('func TestΤεστ (*testing.T )')
      assert Class.new.extend(GoData).is_gotest_test_case('func Testτεστ(*testing.T)')

    end

    it 'must reject invalid gotest function names' do
      assert (not Class.new.extend(GoData).is_gotest_test_case('func Test(*testing.T)'))
      assert (not Class.new.extend(GoData).is_gotest_test_case('func ΤestFoo(*testing.T)'))
      assert (not Class.new.extend(GoData).is_gotest_test_case('func testFoo(*testing.T)'))
      assert (not Class.new.extend(GoData).is_gotest_test_case("func testFoo(*testing.T\n)"))
    end

    it 'must accept valid GoConvey test cases' do
      assert Class.new.extend(GoData).is_GoConvey_test_case('Convey("When calling SyncSignedInUser", t, func()')
      assert Class.new.extend(GoData).is_GoConvey_test_case('Convey ("Should remove org role", func()')
      assert Class.new.extend(GoData).is_GoConvey_test_case('Convey("Should add cert", func() {')
    end

  end

  describe 'when asked to recognize assertions' do

    it 'must accept valid gotest assertions' do
      assert Class.new.extend(GoData).is_gotest_assertion('t.Fatalf("expected to allocate between 1 and 2")')
      assert Class.new.extend(GoData).is_gotest_assertion('Fatal("expected to allocate between 1 and 2")')
      assert Class.new.extend(GoData).is_gotest_assertion('b.Errorf("unable to unmarshal nanosecond data: %s", err.Error())')
      assert Class.new.extend(GoData).is_gotest_assertion('Errorf ("expected to allocate between 1 and 2")')

    end

    it 'must accept valid GoConvey assertions' do
      assert Class.new.extend(GoData).is_GoConvey_assertion('So(transport.TLSClientConfig.InsecureSkipVerify, ShouldEqual, false)')
      assert Class.new.extend(GoData).is_GoConvey_assertion('So(len(transport.TLSClientConfig.Certificates),ShouldEqual, 0)')
      assert Class.new.extend(GoData).is_GoConvey_assertion('So((transport.TLSClientConfig.Certificates),ShouldEqual, 0)')
      assert Class.new.extend(GoData).is_GoConvey_assertion('So(rule1.ContainsUpdates(rule2), ShouldBeFalse)')
      assert Class.new.extend(GoData).is_GoConvey_assertion('So(rule1.ContainsUpdates(rule2),ShouldBeFalse)')
    end

    it 'must accept valid testify assertions' do
      assert Class.new.extend(GoData).is_testify_assertion('assert.NoError(t, node1.AddContainer(createContainer("c1", config)))')
      assert Class.new.extend(GoData).is_testify_assertion('assert.Equal(t, node1.UsedCpus, int64(1))')
      assert Class.new.extend(GoData).is_testify_assertion('Assert.Panics(t,node2.AddContainer(createContainer("c2", config)))')
      assert Class.new.extend(GoData).is_testify_assertion('a.NotEqual(t, node2.UsedCpus, int64(1))')
      assert Class.new.extend(GoData).is_testify_assertion('assert.Nil(t, containers.Get("invalid-id"))')
    end

    it 'must reject invalid testify assertions' do
      assert !Class.new.extend(GoData).is_testify_assertion('aret.NotEqual(t, node1.AddContainer(createContainer("c1", config)))')
      assert !Class.new.extend(GoData).is_testify_assertion('arettttt.NotEqual(t, node1.AddContainer(createContainer("c1", config)))')
      assert !Class.new.extend(GoData).is_testify_assertion('arettttt!NotEqual(t, node1.AddContainer(createContainer("c1", config)))')
      # TODO (GG) Not sure about this one
      assert !Class.new.extend(GoData).is_testify_assertion('A.NotEqual(t, node1.AddContainer(createContainer("c1", config)))')
    end

    it 'must accept valid assertions' do
      assert Class.new.extend(GoData).assertion_filter.call('So(transport.TLSClientConfig.InsecureSkipVerify, ShouldEqual, false)')
      assert Class.new.extend(GoData).assertion_filter.call('Errorf ("expected to allocate between 1 and 2")')
      assert Class.new.extend(GoData).is_testify_assertion('assert.Nil(t, containers.Get("invalid-id"))')
    end

  end

end