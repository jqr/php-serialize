Gem::Specification.new do |spec|
	spec.name = "php-serialize"
	spec.version = "1.1.0"
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
	spec.homepage = "http://www.aagh.net/projects/ruby-php-serialize"
	spec.test_file = "test.rb"
	spec.has_rdoc = true

	spec.add_development_dependency "bundler", "~> 1.15"
	spec.add_development_dependency "rake", "~> 10.0"
end
