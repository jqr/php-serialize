$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require "minitest/autorun"
require "minitest/reporters"
require "minitest/spec"
require "minitest/focus"

require "shellwords"
require "pry"

require "php-serialize"

Minitest::Reporters.use!(
  Minitest::Reporters::ProgressReporter.new(color: true),
  ENV,
  Minitest.backtrace_filter,
)

class Minitest::Spec
  # Helper turn php code into the serialized form by executing it in PHP and
  # serializing the final line.
  #
  #  serialize_php_code(1)   # => "i:1;"
  #  serialize_php_code("
  #   $s = 'Hello';
  #   $s .= ' World!';
  #   $s;
  #  ")                      # => "s:12:\"Hello World!\";"
  def serialize_php_code(code)
    preamble, final = split_php_code(code)
    php = [preamble, "echo serialize(#{final});"].compact.join("\n")
    execute_php(php)
  end

  def session_encode_php_code(code)
    php = ["session_start();", code, "echo session_encode();"].compact.join("\n")
    execute_php(php)
  end

  def split_php_code(code)
    code = code.to_s.strip
    preamble = code.lines
    final = preamble.pop.sub(/;\z/, "")
    [preamble.join(""), final]
  end

  # Calls var_export in PHP and returns the result.
  def var_export(php)
    execute_php("$x = #{php}; echo var_export($x);")
  end

  # Executes the given PHP code, returns the result as a string.
  def execute_php(code)
    cmd = ["php", "-r", code].shelljoin
    result = `#{cmd}`
    raise "Command failed with exit status, #{$?.exitstatus}: #{cmd}" if $?.exitstatus != 0
    result
  end

  def serialize(value, assoc = false)
    PHP.serialize(value, assoc)
  end

  def unserialize(value, class_map = nil, assoc = false)
    PHP.unserialize(value, class_map, assoc)
  end

  # Helper to serialize and then unserialize a Ruby value for easy round-trip
  # testing.
  def reserialize(value)
    unserialize(serialize(value))
  end

  # def php_unserialize(serialized)
  #   var_export("unserialize('#{serialized}')")
  # end

  # def serialized_to_php(value)
  #   php_unserialize(serialize(value))
  # end

  # def serialized_from_php(value)
  #   PHP.unserialize(serialize_php_code(value))
  # end

  def serialize_session(value, assoc = false)
    PHP.serialize_session(value, assoc)
  end
end
