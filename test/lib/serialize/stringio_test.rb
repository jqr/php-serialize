require "test_helper"

describe "StringIO" do
  let(:described_class) { PHP::Serialize::StringIO }

  it "should behave like a normal StringIO" do
    sio = described_class.new("abcdef")
    _(sio.read(3)).must_equal "abc"
    _(sio.read(3)).must_equal "def"
    sio.rewind
    _(sio.read(2)).must_equal "ab"
  end

  describe "read_until" do
    it "should read up to and including the given character" do
      sio = described_class.new("abcdef")
      _(sio.read_until("c")).must_equal "abc"
      _(sio.read_until("e")).must_equal "de"
      sio.rewind
      _(sio.read_until("e")).must_equal "abcde"
    end

    it "should return an empty string if the value doesn't occur" do
      sio = described_class.new("abcdef")
      _(sio.read_until("x")).must_equal ""
    end

    it "should handle repeated calls with the same value" do
      sio = described_class.new("vv")
      _(sio.read_until("v")).must_equal "v"
      _(sio.read_until("v")).must_equal "v"
      _(sio.read_until("v")).must_equal ""
    end

    it "should work with multiple characters" do
      sio = described_class.new("abcdef")
      _(sio.read_until("bc")).must_equal "abc"
      _(sio.read_until("def")).must_equal "def"
    end
  end
end
