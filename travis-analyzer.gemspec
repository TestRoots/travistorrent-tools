# -*- encoding: utf-8 -*-
require 'rake'

Gem::Specification.new do |gem|
  gem.authors       = ["Moritz Beller", "Georgios Gousios"]
  gem.email         = ["moritzbeller@gmx.de", "gousiosg@gmail.com"]
  gem.description   = %q{A framework for the retrieval and the analysis of Travis CI build logs}
  gem.summary       = %q{Retrieve and analyze Travis CI builds}
  gem.homepage      = "https://travistorrent.testroots.org/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "travistorrent-tools"
  gem.require_paths = ["lib"]
  gem.version       = 0.1

  gem.add_dependency "github-linguist", ['>= 4.5']
  gem.add_dependency "rugged", ['>= 0.22']
  gem.add_dependency 'parallel', ['>= 0.7.1']
  gem.add_dependency 'mongo', ['>= 1.12', '< 2.0' ]
  gem.add_dependency 'sequel', ['>= 4.23']
  gem.add_dependency 'trollop', ['>= 2.1.2']
  gem.add_dependency 'mysql2', ['>= 0.3']
  gem.add_dependency 'travis', ['>= 1.7','< 1.9']
  gem.add_dependency 'colorize', ['>= 0.7']
  gem.add_dependency 'activesupport', ['<5.0.0']
  gem.add_dependency 'time_difference'
  gem.add_dependency 'json', ['>= 2.0.0']

end
