module CRT
  module Converters
    # Translates a CRT format string into an array of chtype (Int32) values.
    # Delegates to the BBCode-style Formatter. See CRT::Formatter for syntax.
    def char2chtype(string : String) : {Array(Int32), Int32, Int32}
      CRT::Formatter.parse(string)
    end

    def char_of(chtype : Int32) : Char
      (chtype & 255).chr
    end

    # Returns a plain string from a chtype array (formatting codes omitted).
    def chtype2char(string : Array(Int32)) : String
      String.build do |str|
        string.each do |ch|
          str << char_of(ch)
        end
      end
    end

    def chtype2string(string : Array(Int32)) : String
      chtype2char(string)
    end
  end
end
