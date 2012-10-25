#!/usr/local/bin/ruby
# encoding: utf-8

if RUBY_VERSION >= "1.9"
  # needed, when running in Ruby 1.9.2 -> no stdlib test/unit
  gem 'test-unit'
end
require 'test/unit'
require 'test/unit/ui/console/testrunner'

$:.unshift "lib"
require 'php_serialize'

TestStruct = Struct.new(:name, :value)
class TestClass
	attr_accessor :name
	attr_accessor :value

	def initialize(name = nil, value = nil)
		@name = name
		@value = value
	end

	def to_assoc
		[['name', @name], ['value', @value]]
	end

	def ==(other)
		other.class == self.class and other.name == @name and other.value == @value
	end
end

ClassMap = {
	TestStruct.name.capitalize.intern => TestStruct,
	TestClass.name.capitalize.intern => TestClass
}

class TestPhpSerialize < Test::Unit::TestCase
	def self.test(ruby, php, opts = {})
		if opts[:name]
			name = opts[:name]
		else
			name = ruby.to_s
		end

		define_method("test_#{name}".intern) do
			assert_nothing_thrown do
				serialized = PHP.serialize(ruby)
				assert_equal php, serialized

				unserialized = PHP.unserialize(serialized, ClassMap)
				case ruby
				when Symbol
					assert_equal ruby.to_s, unserialized
				else
					assert_equal ruby, unserialized
				end
			end
		end
	end

	test nil, 'N;'
	test false, 'b:0;'
	test true, 'b:1;'
	test 42, 'i:42;'
	test -42, 'i:-42;'
	test 2147483647, "i:2147483647;", :name => 'Max Fixnum'
	test -2147483648, "i:-2147483648;", :name => 'Min Fixnum'
	test 4.2, 'd:4.2;'
	test 'test', 's:4:"test";'
	test :test, 's:4:"test";', :name => 'Symbol'
	test "\"\n\t\"", "s:4:\"\"\n\t\"\";", :name => 'Complex string'
	test [nil, true, false, 42, 4.2, 'test'], 'a:6:{i:0;N;i:1;b:1;i:2;b:0;i:3;i:42;i:4;d:4.2;i:5;s:4:"test";}',
		:name => 'Array'
	test({'foo' => 'bar', 4 => [5,4,3,2]}, 'a:2:{s:3:"foo";s:3:"bar";i:4;a:4:{i:0;i:5;i:1;i:4;i:2;i:3;i:3;i:2;}}', :name => 'Hash')
	test TestStruct.new("Foo", 65), 'O:10:"teststruct":2:{s:4:"name";s:3:"Foo";s:5:"value";i:65;}',
		:name => 'Struct'
	test TestClass.new("Foo", 65), 'O:9:"testclass":2:{s:4:"name";s:3:"Foo";s:5:"value";i:65;}',
		:name => 'Class'

  # PHP counts multibyte string, not string length
  def test_multibyte_string
    assert_equal  "s:6:\"öäü\";", PHP.serialize("öäü")
  end
	# Verify assoc is passed down calls.
	# Slightly awkward because hashes don't guarantee order.
	def test_assoc
		assert_nothing_raised do
			ruby = {'foo' => ['bar','baz'], 'hash' => {'hash' => 'smoke'}}
			ruby_assoc = [['foo', ['bar','baz']], ['hash', [['hash','smoke']]]]
			phps = [
				'a:2:{s:4:"hash";a:1:{s:4:"hash";s:5:"smoke";}s:3:"foo";a:2:{i:0;s:3:"bar";i:1;s:3:"baz";}}',
				'a:2:{s:3:"foo";a:2:{i:0;s:3:"bar";i:1;s:3:"baz";}s:4:"hash";a:1:{s:4:"hash";s:5:"smoke";}}'
			]
			serialized = PHP.serialize(ruby, true)
			assert phps.include?(serialized)
			unserialized = PHP.unserialize(serialized, true)
			assert_equal ruby_assoc.sort, unserialized.sort
		end
	end

	def test_sessions
		assert_nothing_raised do
			ruby = {'session_id' => 42, 'user_data' => {'uid' => 666}}
			phps = [
				'session_id|i:42;user_data|a:1:{s:3:"uid";i:666;}',
				'user_data|a:1:{s:3:"uid";i:666;}session_id|i:42;'
			]
			unserialized = PHP.unserialize(phps.first)
			assert_equal ruby, unserialized
			serialized = PHP.serialize_session(ruby)
			assert phps.include?(serialized)
		end
	end

  def test_new_struct_creation
    assert_nothing_raised do
      phps = 'O:8:"stdClass":2:{s:3:"url";s:17:"/legacy/index.php";s:8:"dateTime";s:19:"2012-10-24 22:29:13";}'
      unserialized = PHP.unserialize(phps)
    end
  end
end

require 'test/unit/ui/console/testrunner'
Test::Unit::UI::Console::TestRunner.run(TestPhpSerialize)

