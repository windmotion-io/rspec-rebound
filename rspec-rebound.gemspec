require 'English'
require File.expand_path('lib/rspec/rebound/version', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['Federico Aldunate', 'Agustin Fornio']
  gem.email         = ['tech@windmotion.io']
  gem.description   = 'A RSpec extension that automatically retries intermittently failing examples to reduce test flakiness ' \
                      'and improve reliability in your test suite.'
  gem.summary       = 'Retry intermittently failing RSpec examples to eliminate flaky tests and increase test suite stability ' \
                      'without modifying your existing specs.'
  gem.homepage      = 'https://github.com/windmotion-io/rspec-rebound'
  gem.license       = 'MIT'

  gem.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  gem.files         = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  gem.executables   = []
  gem.name          = 'rspec-rebound'
  gem.require_paths = ['lib']
  gem.version       = RSpec::Rebound::VERSION
  gem.add_runtime_dependency 'rspec-core', '~> 3.3'
  gem.add_development_dependency 'debug', '~> 1.0'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rspec', '~> 3.3'
  gem.add_development_dependency 'rubocop', '>= 1.72.1', '< 2.0'
end
