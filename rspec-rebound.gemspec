# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rspec/rebound/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Federico Aldunate", 'Agustin Fornio']
  gem.email         = ["tech@windmotion.io"]
  gem.description   = %q{retry intermittently failing rspec examples again}
  gem.summary       = %q{retry intermittently failing rspec examples again}
  gem.homepage      = "https://github.com/windmotion-io/rspec-rebound"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rspec-rebound"
  gem.require_paths = ["lib"]
  gem.version       = RSpec::Rebound::VERSION
  gem.add_runtime_dependency(%{rspec-core}, '>3.3')
  gem.add_development_dependency %q{appraisal}
  gem.add_development_dependency %q{rspec}
  gem.add_development_dependency %q{byebug}
  gem.add_development_dependency %q{pry-byebug}
end
