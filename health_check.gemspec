# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'health_check/version'

Gem::Specification.new do |gem|
  gem.name          = 'rails_health_check'
  gem.version       = HealthCheck::VERSION
  gem.required_rubygems_version = Gem::Requirement.new('>= 0') if gem.respond_to? :required_rubygems_version=
  gem.authors       = ['Ian Heggie']
  gem.email         = ['ian@heggie.biz']
  gem.summary = 'Simple health check of Rails app for uptime monitoring with Pingdom, NewRelic, EngineYard or uptime.openacs.org etc.'
  gem.description = <<-EOD
  	Fork of https://github.com/ianheggie/health_check.
    Simple health check of Rails app for uptime monitoring with Pingdom, NewRelic, EngineYard or uptime.openacs.org etc.
  EOD
  gem.homepage      = 'https://github.com/FinalCAD/health_check'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.extra_rdoc_files = ['README.rdoc']
  gem.require_paths = ['lib']
  gem.required_ruby_version = '>= 2.2.2'
  gem.add_dependency('rails', ['>= 4.0'])
  gem.add_development_dependency('bundler')
  gem.add_development_dependency('rake', ['>= 0.8.3'])
  gem.add_development_dependency('shoulda', ['~> 2.11.0'])
  gem.add_development_dependency('smarter_bundler', ['>= 0.1.0'])
  gem.add_development_dependency 'sqlite3'
end
