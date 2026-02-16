module CRT::Ncurses
  module Display
    # Tell if a display type is "hidden"
    def self.hidden_display_type?(type : CRT::Ncurses::DisplayType) : Bool
      case type
      when .hchar?, .hint?, .hmixed?, .lhchar?, .lhmixed?, .uhchar?, .uhmixed?
        true
      else
        false
      end
    end

    # Given a character input, check if it is allowed by the display type
    # and return the character to apply, or -1 (ERR) if not allowed.
    def self.filter_by_display_type(type : CRT::Ncurses::DisplayType, input : Int32) : Int32
      result = input

      if !CRT::Ncurses.is_char?(input)
        result = -1
      elsif (type.int? || type.hint?) && !input.chr.ascii_number?
        result = -1
      elsif (type.char? || type.uchar? || type.lchar? || type.uhchar? || type.lhchar?) && input.chr.ascii_number?
        result = -1
      elsif type.viewonly?
        result = -1
      elsif (type.uchar? || type.uhchar? || type.umixed? || type.uhmixed?) && input.chr.ascii_letter?
        result = input.chr.upcase.ord
      elsif (type.lchar? || type.lhchar? || type.lmixed? || type.lhmixed?) && input.chr.ascii_letter?
        result = input.chr.downcase.ord
      end

      result
    end
  end
end
