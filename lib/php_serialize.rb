# frozen_string_literal: true
require "php/serialize/stringio"

module PHP
  # Similar to PHP's serialize, returns a string representing `var` in a form
  # readable by`PHP.unserialize` and PHP's `unserialize()` should both be
  # able to load.
  #
  #  PHP.serialize("abc")     # => 's:3:"abc";'
  #  PHP.serialize([5, 6])    # => 'a:2:{i:0;i:5;i:1;i:6;}'
  #  PHP.serialize(abc: 123)  # => 'a:1:{s:3:"abc";i:123;}'
  #
  # Array, Hash, Fixnum, Float, True/FalseClass, NilClass, String and Struct
  # are supported; as are objects which support the to_assoc method, which
  # returns an array of the form [['attr_name', 'value']..].  Anything else
  # will raise a TypeError.
  #
  # If `assoc` is specified, Arrays who's element are all two value Arrays
  # will be assumed to be an associative array, and will be serialized as a
  # PHP associative array rather than a multidimensional array.
  def self.serialize(var, assoc = false)
    case var
    when Array
      if assoc && var.all? { |i| i.is_a?(Array) && i.size == 2 }
        serialize(var.to_h, assoc)
      else
        serialize(var.map.with_index { |v, i| [i, v] }.to_h, assoc)
      end

    when Hash
      "a:" + serialize_children(var, assoc)

    when Struct
      klass = var.class.to_s.downcase
      %Q[O:#{klass.bytesize}:"#{klass}":] + serialize_children(var.each_pair, assoc)

    when String, Symbol
      %Q[s:#{var.to_s.bytesize}:"#{var}";]

    when Integer
      "i:#{var};"

    when Float
      "d:#{var};"

    when NilClass
      "N;"

    when FalseClass, TrueClass
      "b:#{var ? 1 : 0};"

    else
      if var.respond_to?(:to_assoc)
        klass = var.class.to_s.downcase
        %Q[O:#{klass.bytesize}:"#{klass}":] + serialize_children(var.to_assoc, assoc)
      else
        raise TypeError, "Unable to serialize type #{var.class}"
      end
    end
  end

  # Internal helper which serializes the childen portion of Objects and
  # Associtive Array's.
  #
  #  serialize_children([1, 2])  # => "2:{i:5;N;i:6;N;}"
  #
  # Which always has the format:
  #
  #  <number of pairs>:{<serialized_key><serialized_value>...}
  def self.serialize_children(children, assoc = false)
    children.size.to_s + ":{" + children.map { |k, v| serialize(k, assoc) + serialize(v, assoc) }.join("") + "}"
  end

  # Like PHP.serialize, but only accepts a Hash or associative Array as the root
  # type. The results are returned in PHP session format.
  #
  #  PHP.serialize_session(abc: 123)  # => "abc|i:123;"
  def self.serialize_session(var, assoc = false)
    unless var.is_a?(Hash) || var.is_a?(Array)
      raise TypeError, "Unable to serialize sessions with top level types other than Hash and associative Array"
    end
    var.to_a.map do |a|
      if !a.is_a?(Array) || a.size != 2
        raise TypeError, "Array is not associative"
      end
      key, value = a
      if key.to_s.include?("|")
        raise IndexError, "Top level keys may not contain pipes(|)"
      end
      "#{key}|#{serialize(value, assoc)}"
    end.join("")
  end

  # Similar to PHP's `unserialize()`, returns an object containing the
  # reconstituted data from `PHP.serialize` or PHP's `serialize()`.
  #
  #  PHP.unserialize('s:3:"abc";')              # => "abc"
  #  PHP.unserialize('a:2:{i:0;i:5;i:1;i:6;}')  # => [5, 6]
  #  PHP.unserialize('a:1:{s:3:"abc";i:123;}')  # => {"abc"=>123}
  #
  # If a PHP array (associative; like an ordered hash) is encountered, it
  # scans the keys; if they're all incrementing integers counting from 0,
  # it's unserialized as an Array, otherwise it's unserialized as a Hash.
  # Note: this will lose ordering.  To avoid this, specify assoc=true, and it
  # will be unserialized as an associative array: [[key,value],...]
  #
  # If a serialized object is encountered, the hash 'classmap' is searched for
  # the class name (as a symbol).  Since PHP classnames are not
  # case-preserving, this *must* be a .capitalize()d representation.  The
  # value is expected to be the class itself; i.e. something you could
  # call .new on.
  #
  # If it's not found in 'classmap', the current constant namespace is
  # searched, and failing that, a new Struct(classname) is generated, with
  # the arguments for .new specified in the same order PHP provided; since
  # PHP uses hashes to represent attributes, this should be the same order
  # they're specified in PHP, but this is untested.
  #
  # each serialized attribute is sent to the new object using the respective
  # {attribute}=() method; you'll get a NameError if the method doesn't
  # exist.
  #
  # Array, Hash, Fixnum, Float, True/FalseClass, NilClass and String should be
  # returned identically (i.e. foo == PHP.unserialize(PHP.serialize(foo)) for
  # these types); Struct should be too, provided it's in the namespace
  # Module.const_get within unserialize() can see, or you gave it the same
  # name in the Struct.new(<structname>), otherwise you should provide it in
  # classmap.
  def self.unserialize(string, classmap = nil, assoc = false)
    # Allow `classmap` to be omitted and the 2nd argument to be understood as
    # `assoc`.
    if classmap == true || classmap == false
      assoc = classmap
      classmap = {}
    end
    classmap ||= {}

    ret = nil
    original_encoding = string.encoding
    string = Serialize::StringIO.new(string.dup.force_encoding('BINARY'))
    while string.string[string.pos, 32] =~ /^(\w+)\|/ # session_name|serialized_data
      ret ||= {}
      string.pos += $&.size
      ret[$1] = do_unserialize(string, classmap, assoc, original_encoding)
    end

    ret || do_unserialize(string, classmap, assoc, original_encoding)
  end

  private

  def self.do_unserialize(string, classmap, assoc, original_encoding)
    # determine a type
    type = string.read(2)[0,1]
    case type
    when "a" # associative array, a:length:{[index][value]...}
      count = string.read_until("{").to_i
      val = Array.new
      count.times do |i|
        val << [do_unserialize(string, classmap, assoc, original_encoding), do_unserialize(string, classmap, assoc, original_encoding)]
      end
      string.read(1) # skip the ending }

      # now, we have an associative array, let's clean it up a bit...
      # arrays have all numeric indexes, in order; otherwise we assume a hash
      array = true
      i = 0
      val.each do |key, _|
        if key != i # wrong index -> assume hash
          array = false
          break
        end
        i += 1
      end

      val = val.map { |tuple|
        tuple.map { |it|
          it.kind_of?(String) ? it.force_encoding(original_encoding) : it
        }
      }

      if array
        val.map! { |_, value| value }
      elsif !assoc
        val = Hash[val]
      end

      val

    when "O" # object, O:length:"class":length:{[attribute][value]...}
      # class name (lowercase in PHP, grr)
      len = string.read_until(":").to_i + 3 # quotes, seperator
      klass = string.read(len)[1...-2].capitalize.to_sym # read it, kill useless quotes

      # read the attributes
      attrs = []
      len = string.read_until('{').to_i

      len.times do
        attr = (do_unserialize(string, classmap, assoc, original_encoding))
        attrs << [attr, do_unserialize(string, classmap, assoc, original_encoding)]
      end
      string.read(1)

      val = nil
      # See if we need to map to a particular object
      if classmap.has_key?(klass)
        val = classmap[klass].new
      elsif Struct.const_defined?(klass) # Nope; see if there's a Struct
        classmap[klass] = val = Struct.const_get(klass)
        val = val.new
      else # Nope; see if there's a Constant
        begin
          classmap[klass] = val = Module.const_get(klass)

          val = val.new
        rescue NameError # Nope; make a new Struct
          classmap[klass] = val = Struct.new(klass.to_s, *attrs.map { |v| v[0].to_s })
          val = val.new
        end
      end

      attrs.each do |attr, v|
        val.__send__("#{attr}=", v)
      end

      val

    when "s" # string, s:length:"data";
      len = string.read_until(':').to_i + 3 # quotes, separator
      full_val = string.read(len)
      raise "String value did not begin with a quote(\") character." unless full_val[0] == '"'
      unless full_val[-2, 2] == '";'
        raise "String value did not end with quote semicolon(\";), is #{original_encoding.name} the correct encoding?"
      end
      full_val[1...-2].force_encoding(original_encoding) # read it, kill useless quotes

    when "i" # integer, i:123
      string.read_until(';').to_i

    when "d" # double (float), d:1.23
      string.read_until(';').to_f

    when "N" # NULL, N;
      nil

    when "b" # bool, b:0 or 1
      string.read(2)[0] == "1"

    else
      raise TypeError, "Unable to unserialize type '#{type}'"
    end

    # TODO: error on peek?

  end
end
