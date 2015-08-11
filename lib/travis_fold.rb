class TravisFold
  attr_accessor :fold
  attr_accessor :content
  attr_accessor :duration

  def initialize(fold)
    @fold = fold
    @content = Array.new
  end
end