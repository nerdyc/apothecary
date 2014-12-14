# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apothecary/version'

Gem::Specification.new do |spec|
  spec.name          = "apothecary"
  spec.version       = Apothecary::VERSION
  spec.authors       = ["Christian Niles"]
  spec.email         = ["christian@nerdyc.com"]
  spec.summary       = %q{Create executable documentation for your API}
  spec.description   = %q{Document and test your API at the same time.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  
  spec.add_development_dependency "rspec"
end
