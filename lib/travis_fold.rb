# Models TravisFolds, which are special markers in Travis CI-generated that separate different stages of the build
# process

class TravisFold
  attr_accessor :fold
  attr_accessor :content
  attr_accessor :duration

  def initialize(fold)
    @fold = fold
    @content = Array.new
  end
end