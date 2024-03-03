# frozen_string_literal: true
require "stringio"

module PHP
  module Serialize
    class StringIO < StringIO
      # Reads data from the buffer until `search` is found. The returned string
      # will include `search`.
      #
      #  sio = StringIO.new("abcdef")
      #  sio.read_until("c")  # => "abc"
      #  sio.read_until("e")  # => "de"
      #  sio.read_until("x")  # => ""
      def read_until(search)
        if index = string.index(search, pos)
          read(index - pos + search.size)
        else
          ""
        end
      end
    end
  end
end
