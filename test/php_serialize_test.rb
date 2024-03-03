# frozen_string_literal: true
require "test_helper"

describe "serialize/unserialize" do
  it "should handle nil" do
    serialized = serialize_php_code("NULL")
    _(unserialize(serialized)).must_be_nil
    _(  serialize(nil       )).must_equal serialized
  end

  it "should handle false" do
    serialized = serialize_php_code("false")

    _(unserialize(serialized)).must_equal false
    _(  serialize(false     )).must_equal serialized
  end

  it "should handle true" do
    serialized = serialize_php_code("true")
    _(unserialize(serialized)).must_equal true
    _(  serialize(true      )).must_equal serialized
  end

  describe "integers" do
    it "should handle positive" do
      serialized = serialize_php_code("42")
      _(unserialize(serialized)).must_equal         42
      _(  serialize(        42)).must_equal serialized

      _(reserialize(       999)).must_equal 999
    end

    it "should handle negative" do
      serialized = serialize_php_code("-37")
      _(unserialize(serialized)).must_equal(       -37)
      _(  serialize(       -37)).must_equal serialized

      _(reserialize(      -999)).must_equal(      -999)
    end

    it "should handle large values" do
      _(reserialize( 2147483647)).must_equal  2147483647
      _(reserialize(-2147483648)).must_equal(-2147483648)
    end
  end

  describe "floats (doubles)" do
    it "should handle positives" do
      serialized = serialize_php_code("4.2")
      _(unserialize(serialized)).must_equal        4.2
      _(  serialize(       4.2)).must_equal serialized

      _(reserialize(      1.23)).must_equal       1.23
    end

    it "should handle negatives" do
      serialized = serialize_php_code("-1.23")
      _(unserialize(serialized)).must_equal(     -1.23)
      _(  serialize(     -1.23)).must_equal serialized

      _(reserialize(     -4.2 )).must_equal(      -4.2)
    end

    it "should handle large values" do
      avogadro = 6.023 * 10 ** 23
      _(reserialize( avogadro)).must_equal  avogadro
      _(reserialize(-avogadro)).must_equal(-avogadro)
    end
  end

  describe "strings" do
    it "should handle simple values" do
      serialized = serialize_php_code("'abc'")
      _(unserialize(serialized)).must_equal "abc"
      _(  serialize("abc"     )).must_equal serialized

      _(reserialize("1337"    )).must_equal "1337"
    end

    it "should handle multibyte strings" do
      serialized = serialize_php_code("'öäü'")
      _(             serialized).must_equal "s:6:\"öäü\";"
      _(  serialize("öäü"     )).must_equal serialized
      _(unserialize(serialized)).must_equal "öäü"

      serialized = serialize_php_code("'ああ'")
      _(             serialized).must_equal "s:6:\"ああ\";"
      _(unserialize(serialized)).must_equal "ああ"
      _(  serialize("ああ"     )).must_equal serialized

      serialized = serialize_php_code("'🤷‍♂️'")
      _(             serialized).must_equal "s:13:\"🤷‍♂️\";"
      _(unserialize(serialized)).must_equal "🤷‍♂️"
      _(  serialize("🤷‍♂️"     )).must_equal serialized
    end

    it "should handle non-unicode strings" do
      a_umlat = 228.chr.force_encoding("ISO-8859-1")  # ä in ISO-8859-1s

      # Haven't figured out the easy way to pass this encoding to PHP's CLI.
      serialized = "s:1:\"#{a_umlat}\";".force_encoding("ISO-8859-1")
      _(serialized.encoding.name).must_equal "ISO-8859-1"

      _(unserialize(serialized)).must_equal a_umlat
      _(  serialize(a_umlat   )).must_equal serialized
    end

    it "should not modify encoding of input" do
      original = String.new('s:3:"abc";', encoding: "ISO-8859-1")
      _(original.encoding.name).must_equal "ISO-8859-1"

      PHP.unserialize(original)

      _(original.encoding.name).must_equal "ISO-8859-1"
    end

    it "should error obviously on malformed strings due to encoding size differences" do
      original = String.new('s:1:"ä";') # Actually UTF-8 string of 2 bytes
      e = _(-> { PHP.unserialize(original) }).must_raise RuntimeError
      _(e.message).must_match(/quote semicolon.*UTF-8.*correct/)
    end

    it "should encode symbols as strings" do
      _(  serialize(:abc      )).must_equal serialize("abc")
      _(reserialize(:abc      )).must_equal "abc"
    end
  end

  describe "arrays" do
    it "should handle empty arrays" do
      serialized = serialize_php_code("[]")
      _(unserialize(serialized)).must_equal []
      _(  serialize([]        )).must_equal serialized
    end

    it "should handle simple value arrays" do
      serialized = serialize_php_code("[5, 6]")
      _(unserialize(serialized)).must_equal [5, 6]
      _(  serialize([5, 6]    )).must_equal serialized

      serialized = serialize_php_code("[NULL, true, false]")
      _(unserialize(serialized        )).must_equal [nil, true, false]
      _(  serialize([nil, true, false])).must_equal serialized

      serialized = serialize_php_code("['x', 'y']")
      _(unserialize(serialized)).must_equal ["x", "y"]
      _(  serialize(["x", "y"])).must_equal serialized
    end

    it "should handle nested arrays" do
      serialized = serialize_php_code("[1, [2, 3, [4]], 5]")
      _(unserialize(serialized         )).must_equal [1, [2, 3, [4]], 5]
      _(  serialize([1, [2, 3, [4]], 5])).must_equal serialized
    end

    it "should handle assoc = true" do
      skip "inconsistent"
      # serialized = serialize_php_code("['a', 'b']")
      serialized = serialize_php_code("array('x'=>5,'y'=>6)")
      _(unserialize(serialized, false)).must_equal "x" => 5, "y" => 6
      _(unserialize(serialized, true )).must_equal [["x", 5], ["y", 6]]

      serialized = serialize_php_code("array(0=>5,1=>6)")
      _(unserialize(serialized, false)).must_equal [5, 6]
      _(unserialize(serialized, true )).must_equal [[0, 5], [1, 6]]
    end
  end

  describe "hashes" do
    # Not possible due to empty associative arrays being identical to simple
    # arrays in PHP.
    # it "should handle empty hashes" do
    #   serialized = serialize_php_code("array()")
    #   _(  serialize({}        )).must_equal serialized
    #   _(unserialize(serialized)).must_equal {}
    # end

    it "should handle simple values" do
      serialized = serialize_php_code("array('x'=>1)")
      _(unserialize(serialized)).must_equal "x" => 1
      _(  serialize("x" => 1  )).must_equal serialized

      serialized = serialize_php_code("array('x'=>1, 'y'=>2)")
      _(unserialize(serialized        )).must_equal "x" => 1, "y" => 2
      _(  serialize("x" => 1, "y" => 2)).must_equal serialized
    end

    it "should handle nesting" do
      serialized = serialize_php_code("array('x'=>1, 'y'=>array('z'=>3))")
      _(unserialize(serialized                   )).must_equal "x" => 1, "y" => { "z" => 3 }
      _(  serialize("x" => 1, "y" => { "z" => 3 })).must_equal serialized
    end

    it "should handle nesting of multibyte unicode strings" do
      serialized = serialize_php_code("array('ö'=>array('ä'=>'ü'))")
      _(unserialize(serialized           )).must_equal "ö" => { "ä" => "ü" }
      _(  serialize("ö" => { "ä" => "ü" })).must_equal serialized
    end

    it "should handle assoc = true"

    # TODO: simplify and rewrite in spec style
    # Verify assoc is passed down calls.
    # Slightly awkward because hashes don't guarantee order.
    def test_assoc
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

    # TODO: simplify and rewrite in spec style
    # Multibyte version.
    # Verify assoc is passed down calls.
    # Slightly awkward because hashes don't guarantee order.
    def test_assoc_multibyte
      ruby = {'ああ' => ['öäü','漢字'], 'hash' => {'おはよう' => 'smoke'}}
      ruby_assoc = [['ああ', ['öäü','漢字']], ['hash', [['おはよう','smoke']]]]
      phps = [
        'a:2:{s:6:"ああ";a:2:{i:0;s:6:"öäü";i:1;s:6:"漢字";}s:4:"hash";a:1:{s:12:"おはよう";s:5:"smoke";}}',
        'a:2:{s:4:"hash";a:1:{s:12:"おはよう";s:5:"smoke";}s:6:"ああ";a:2:{i:0;s:6:"öäü";i:1;s:6:"漢字";}}'
      ]
      serialized = PHP.serialize(ruby, true)
      # require "pry"
      # binding.pry
      assert phps.include?(serialized)
      unserialized = PHP.unserialize(serialized, true)
      assert_equal ruby_assoc.sort, unserialized.sort
    end
  end

  describe "structs" do
    MyStruct = Struct.new(:p1, :p2)

    let(:serialized) {
      serialize_php_code <<~PHP
        class MyStruct
        {
          public $p1;
          public $p2;
        }
        $o = new MyStruct();
        $o->p1 = 1;
        $o->p2 = 2;
        $o;
      PHP
    }

    it "should handle handle mapped structs" do
      object = MyStruct.new(1, 2)

      _(                                     serialized).must_equal 'O:8:"MyStruct":2:{s:2:"p1";i:1;s:2:"p2";i:2;}'

      _(unserialize(serialized, { Mystruct: MyStruct })).must_equal object
      # _(  serialize(object)).must_equal serialized
    end

    it "should handle unserializing to dynamically created struct" do
      _(unserialize(serialized                        )).must_equal Struct::Mystruct.new(1, 2) # Creates Struct
      _(unserialize(serialized                        )).must_equal Struct::Mystruct.new(1, 2) # Re-uses existing Struct
    end
  end

  describe "classes" do
    class MyClass
      attr_accessor :p1, :p2

      def to_assoc
        [["p1", p1], ["p2", p2]]
      end

      def ==(other)
        other.class == self.class && other.p1 == p1 && other.p2 == p2
      end
    end

    it "should handle classes with to_assoc and attribute writers" do
      serialized = serialize_php_code <<~PHP
        class MyClass
        {
          public $p1;
          public $p2;
        }
        $o = new MyClass();
        $o->p1 = 1;
        $o->p2 = 2;
        $o;
      PHP

      object = MyClass.new
      object.p1 = 1
      object.p2 = 2

      _(                                   serialized).must_equal 'O:7:"MyClass":2:{s:2:"p1";i:1;s:2:"p2";i:2;}'

      _(unserialize(serialized, { Myclass: MyClass })).must_equal object
      # Preserving previous downcase behavior.
      _(  serialize(object                          )).must_equal serialized.downcase.capitalize
    end
  end

  describe "sessions" do
    let(:serialized) {
      session_encode_php_code <<~PHP
        $_SESSION["id"]   = 42;
        $_SESSION["user"] = array("id"=>666);
      PHP
    }

    it "should serialize hash" do
      _(                                              serialized).must_equal 'id|i:42;user|a:1:{s:2:"id";i:666;}'
      _(                                 unserialize(serialized)).must_equal "id" => 42, "user" => { "id" => 666 }
      _(serialize_session("id" => 42, "user" => { "id" => 666 })).must_equal serialized
    end

    it "should serialize assoc = true" do
      _(                                              serialized).must_equal 'id|i:42;user|a:1:{s:2:"id";i:666;}'
      # Preserving previous behavior.
      _(                                  unserialize(serialized, true)).must_equal "id" => 42, "user" => [["id", 666]]
      _(serialize_session([["id", 42], ["user", { "id" => 666}]], true)).must_equal serialized
    end
  end
end
