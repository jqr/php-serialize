lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "php/serialize/version"

Gem::Specification.new do |spec|
  spec.name = "php-serialize"
  spec.version = PHP::Serialize::VERSION
  spec.license = "MIT"
  spec.author = "Thomas Hurst"
  spec.email = "tom@hur.st"
  spec.summary = "Ruby analogs to PHP's serialize() and unserialize() functions"
  spec.description = <<-EOF
    This module provides two methods: PHP.serialize() and PHP.unserialize(), both
    of which should be compatible with the similarly named functions in PHP.

    It can also serialize and unserialize PHP sessions.
  EOF

  spec.files = Dir["lib/*.rb"]
  spec.require_path = "lib/"
  spec.homepage = "https://github.com/jqr/php-serialize"
  spec.test_files = Dir["test/*_test.rb"]

  spec.add_development_dependency "bundler", ">= 2.5.6"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-minitest"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-focus"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", ">= 13.1.0"

  spec.required_ruby_version = '>= 2.4'
end
