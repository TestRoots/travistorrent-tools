#
# (c) 2016 -- 2017 Georgios Gousios <gousiosg@gmail.com>
#

require 'ghtorrent_extractor/comment_stripper'

module GoData

  include CommentStripper

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a test file
  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end

      # https://golang.org/pkg/go/build/
      # http://stackoverflow.com/questions/25161774/what-are-conventions-for-filenames-in-go
      path.end_with?('_test.go')
    end
  end

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a src file
  def src_file_filter
    lambda do |f|
      f[:path].end_with?('.go') and not test_file_filter.call(f[:path])
    end
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents a test case declaration
  def test_case_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents an assertion
  def assertion_filter
    raise Exception.new("Unimplemented")
  end


  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
