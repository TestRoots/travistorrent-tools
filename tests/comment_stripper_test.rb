require 'minitest/autorun'
require 'ghtorrent_extractor/comment_stripper'

class MyTest < MiniTest::Test

  include CommentStripper


  def test_c_style_simple_1
    str = '//test'
    stripped = strip_c_style_comments(str)
    assert_equal('', stripped)
  end

  def test_c_style_simple_2
    str = 'foo//test'
    stripped = strip_c_style_comments(str)
    assert_equal('foo', stripped)
  end

  def test_c_style_simple_3
    str = "foo//test\n"
    stripped = strip_c_style_comments(str)
    assert_equal("foo\n", stripped)
  end

  def test_c_style_multiline_1
    str = '/***/'
    stripped = strip_c_style_comments(str)
    assert_equal('', stripped)
  end

  def test_c_style_multiline_2
    str = <<-END
/*
 * Foo bar
 */
    END

    stripped = strip_c_style_comments(str)
    assert_equal("\n", stripped)
  end

  def test_c_style_multiline_3
    str = <<-END
/*
 * //Foo bar
 */
    END

    stripped = strip_c_style_comments(str)
    assert_equal("\n", stripped)
  end

  def test_c_style_multiline_4
    str = <<-END
/*
 * //Foo bar
 */
test
    END

    stripped = strip_c_style_comments(str)
    assert_equal("\ntest\n", stripped)
  end

end