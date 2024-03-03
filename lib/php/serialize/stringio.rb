# frozen_string_literal: true
require "stringio"

module PHP
  module Serialize
    class StringIO < StringIO
      # Reads data from the buffer until `char` is found. The returned string
      # will include `char`.
      def read_until(char)
        val, cpos = '', pos
        if idx = string.index(char, cpos)
          val = read(idx - cpos + 1)
        end
        val
      end
    end
  end
end
