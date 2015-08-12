#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

require 'comment_stripper'

module JavaData

  include CommentStripper

  def src_files(sha)
    files_at_commit(sha, src_file_filter)
  end

  def src_lines(sha)
    count_lines(src_files(sha))
  end

  def test_files(sha)
    files_at_commit(sha, test_file_filter)
  end

  def test_lines(sha)
    count_lines(test_files(sha))
  end

  def num_test_cases(sha)
    test_files(sha).map {|f|
      buff = stripped(f)

      junit4 = buff.lines.select{|l| not l.match(/@Test/).nil?}.size

      if junit4 == 0 #Try Junit 3 style
        buff.scan(
          /(public|protected|private|static|\s) +[\w<>\[\]]+\s+(\w+) *\([^\)]*\) *(\{?|[^;])/
        ).map{ |x|
          if x[1].match(/^test/) then 1 else 0 end
        }.reduce(0){|acc, x| acc + x}
      else
        junit4
      end
    }.reduce(0){|acc, x| acc + x}
  end

  def num_assertions(pr_id)
    count_lines(test_files(pr_id), lambda{|l| not l.match(/assert/).nil?})
  end

  def src_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java')and not test_file_filter.call(f)
    }
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java') and
          (not path.match(/tests?\//).nil? or not path.match(/[tT]est.java/).nil?)
    }
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
