# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rspec/rebound/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Federico Aldunate", 'Agustin Fornio']
  gem.email         = ["tech@windmotion.io"]
  gem.description   = %q{A RSpec extension that automatically retries intermittently failing examples to reduce test flakiness and improve reliability in your test suite.}
  gem.summary       = %q{Retry intermittently failing RSpec examples to eliminate flaky tests and increase test suite stability without modifying your existing specs.}
  gem.homepage      = "https://github.com/windmotion-io/rspec-rebound"
  gem.license       = "MIT"
  
  gem.required_ruby_version = Gem::Requirement.new(">= 2.7.0")
  
  gem.files         = `git ls-files`.split($\)
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rspec-rebound"
  gem.require_paths = ["lib"]
  gem.version       = RSpec::Rebound::VERSION
  gem.add_runtime_dependency "rspec-core", "~> 3.3"
  gem.add_development_dependency "rspec", "~> 3.3"
  gem.add_development_dependency "debug", "~> 1.0"
end
