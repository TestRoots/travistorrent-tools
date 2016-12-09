#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
#

require_relative 'comment_stripper'

module PythonData

  include CommentStripper

  def docstring_tests(sha)
    docstrings(sha).reduce(0) do |acc, docstring|
      in_test = false
      tests = 0
      docstring.lines.each do |x|

        if in_test == false
          if x.match(/^\s+>>>/)
            in_test = true
            tests += 1
          end
        else
          in_test = false unless x.match(/^\s+>>>/)
        end
      end
      acc + tests
    end
  end

  def num_test_cases(sha)
    docstring_tests(sha) + normal_tests(sha)
  end

  def normal_tests(sha)
    test_files(sha).reduce(0) do |acc, f|
      cases = stripped(f).scan(/\s*def\s* test_(.*)\(.*\):/).size
      acc + cases
    end
  end

  def num_assertions(sha)
    ds_tests = docstrings(sha).reduce(0) do |acc, docstring|
      in_test = false
      asserts = 0
      docstring.lines.each do |x|

        if in_test == false
          if x.match(/^\s+>>>/)
            in_test = true
          end
        else
          asserts += 1
          in_test = false unless x.match(/^\s+>>>/)
        end
      end
      acc + asserts
    end

    normal_tests = test_files(sha).reduce(0) do |acc, f|
      cases = stripped(f).lines.select{|l| not l.match(/assert/).nil?}
      acc + cases.size
    end
    Thread.current[:ds_cache] = {} # Hacky optimization to avoid memory problems
    ds_tests + normal_tests
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      # http://pytest.org/latest/goodpractises.html#conventions-for-python-test-discovery
      # Path points to a python file named as foo_test.py or test_foo.py or test.py
      # or it contains a test directory
      path.end_with?('.py') and(
          (
            not path.match(/test_.+/i).nil? or
            not path.match(/.+_test/i).nil? or
            not path.match(/tests?/i).nil?
          ) or (
            not path.match(/test\//).nil?
          )
      )
    }
  end

  def src_file_filter
    lambda { |f|
      f[:path].end_with?('.py') and not test_file_filter.call(f[:path])
    }
  end

  def test_case_filter
    lambda {|l|
      not l.match(/\s*def\s* test_(.*)\(.*\):/).nil?
    }
  end

  def assertion_filter
    lambda{|l| not l.match(/assert/).nil?}
  end

  def strip_comments(buff)
    strip_python_multiline_comments(strip_shell_style_comments(buff))
  end

  def strip_python_multiline_comments(buff)
    out = []
    in_comment = false
    buff.lines.each do |line|
      if line.match(/^\s*["']{3}/)
        in_comment = !in_comment
        next
      end

      unless in_comment
        out << line
      end
    end
    out.flatten.reduce(''){|acc, x| acc + x}
  end

  def ml_comment_regexps
    [/["']{3}(.+?)["']{3}/m]
  end

  private

  def docstrings(sha)
    Thread.current[:ds_cache] ||= {}
    if Thread.current[:ds_cache][sha].nil?
      docstr = (src_files(sha) + test_files(sha)).flat_map do |f|
          buff = git.read(f[:oid]).data
          buff.scan(ml_comment_regexps[0])
          end
      Thread.current[:ds_cache][sha] = docstr.flatten
    end
    Thread.current[:ds_cache][sha]
  end
end
