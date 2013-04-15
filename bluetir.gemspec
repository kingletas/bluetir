# -*- encoding: utf-8 -*-
require File.expand_path('../lib/bluetir/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Luis Tineo"]
  gem.email         = ["letas@kingletas.com"]
  gem.description   = %q{A test suite using watir to test sites}
  gem.summary       = %q{A very simple test suite for magento using watir}
  gem.homepage      = "git@bitbucket.org/kingletas/bluetir.git"
  gem.license       = 'MIT'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "bluetir"
  gem.require_paths = ["lib"]
  gem.version       = Bluetir::VERSION
end
