# frozen_string_literal: true
require "stringio"

module PHP
  module Serialize
    class StringIO < StringIO
      # Reads data from the buffer until `search` is found. The returned string
      # will include `char`.
      def read_until(search)
        val, cpos = '', pos
        if idx = string.index(search, cpos)
          val = read(idx - cpos + search.size)
        end
        val
      end
    end
  end
end
