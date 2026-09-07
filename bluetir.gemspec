# frozen_string_literal: true

require_relative 'lib/bluetir/version'

Gem::Specification.new do |gem|
  gem.name          = 'bluetir'
  gem.version       = Bluetir::VERSION
  gem.authors       = ['Luis Tineo']
  gem.email         = ['letas@kingletas.com']
  gem.summary       = 'A black-box deployment test suite for Magento, driven by YAML.'
  gem.description   = 'Bluetir drives a real browser through a Magento storefront to prove a ' \
                      'deployment works: it adds products to the cart, places an order, and ' \
                      'asserts the text of every page it passes through. The storefront it ' \
                      'drives is described in YAML rather than in Ruby, so one suite can test ' \
                      'more than one store.'
  gem.homepage      = 'https://github.com/kingletas/bluetir'
  gem.license       = 'MIT'

  # 3.3 rather than 3.2 because selenium-webdriver requires it, and a floor
  # this gem cannot actually install on is not a floor.
  gem.required_ruby_version = '>= 3.3'

  # docs/ is in here because the README links into it, and a link that only
  # resolves in the repository is a broken one for anyone reading the gem.
  gem.files = Dir['lib/**/*.rb', 'etc/**/*.yml', 'bin/*', 'docs/*.md', '*.md', 'LICENSE']
  gem.bindir      = 'bin'
  gem.executables = ['bluetir']
  gem.require_paths = ['lib']

  # source_code_uri is not repeated: rubygems.org shows only the first key with
  # a given uri, so duplicating the homepage there just loses a link.
  gem.metadata = {
    'homepage_uri' => gem.homepage,
    'changelog_uri' => "#{gem.homepage}/blob/development/CHANGELOG.md",
    'bug_tracker_uri' => "#{gem.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  gem.add_dependency 'net-smtp', '~> 0.5'
  gem.add_dependency 'watir', '~> 7.3'
end
