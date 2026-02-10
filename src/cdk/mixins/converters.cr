module CDK
  module Converters
    def encode_attribute(string : String, from : Int32, mask : Array(Int32)) : Int32
      mask << 0
      if from + 1 < string.size
        case string[from + 1]
        when 'B'
          mask[mask.size - 1] = LibNCurses::Attribute::Bold.value.to_i32
        when 'D'
          mask[mask.size - 1] = LibNCurses::Attribute::Dim.value.to_i32
        when 'K'
          mask[mask.size - 1] = LibNCurses::Attribute::Blink.value.to_i32
        when 'R'
          mask[mask.size - 1] = LibNCurses::Attribute::Reverse.value.to_i32
        when 'S'
          mask[mask.size - 1] = LibNCurses::Attribute::Standout.value.to_i32
        when 'U'
          mask[mask.size - 1] = LibNCurses::Attribute::Underline.value.to_i32
        end
      end

      if mask[mask.size - 1] != 0
        from += 1
      elsif from + 2 < string.size && string[from + 1].ascii_number? && string[from + 2].ascii_number?
        if NCurses.has_colors?
          pair = string[from + 1..from + 2].to_i
          mask[mask.size - 1] = (pair << 8) # COLOR_PAIR equivalent
        else
          mask[mask.size - 1] = LibNCurses::Attribute::Bold.value.to_i32
        end
        from += 2
      elsif from + 1 < string.size && string[from + 1].ascii_number?
        if NCurses.has_colors?
          pair = (string[from + 1] - '0').to_i
          mask[mask.size - 1] = (pair << 8)
        else
          mask[mask.size - 1] = LibNCurses::Attribute::Bold.value.to_i32
        end
        from += 1
      end

      from
    end

    # Translates a CDK format string into an array of chtype (Int32) values.
    # Format markers like </B>, </U>, </24>, etc. control attributes.
    # `to` receives the display length, `align` receives the alignment.
    def char2chtype(string : String, to : Array(Int32), align : Array(Int32)) : Array(Int32)
      to << 0
      align << CDK::LEFT
      result = [] of Int32

      return result if string.empty?

      attrib = 0 # Ncurses::A_NORMAL
      start = 0
      used = 0

      # Look for an alignment marker
      if string.size >= 3 && string[0] == CDK::L_MARKER
        if string[1] == 'C' && string[2] == CDK::R_MARKER
          align[align.size - 1] = CDK::CENTER
          start = 3
        elsif string[1] == 'R' && string[2] == CDK::R_MARKER
          align[align.size - 1] = CDK::RIGHT
          start = 3
        elsif string[1] == 'L' && string[2] == CDK::R_MARKER
          start = 3
        end
      end

      inside_marker = false
      from = start

      while from < string.size
        if !inside_marker
          if from + 1 < string.size && string[from] == CDK::L_MARKER &&
             (string[from + 1] == '/' || string[from + 1] == '!' || string[from + 1] == '#')
            inside_marker = true
          elsif from + 1 < string.size && string[from] == '\\' && string[from + 1] == CDK::L_MARKER
            from += 1
            result << (string[from].ord | attrib)
            used += 1
          elsif string[from] == '\t'
            loop do
              result << ' '.ord
              used += 1
              break unless (used & 7) != 0
            end
          else
            result << (string[from].ord | attrib)
            used += 1
          end
        else
          case string[from]
          when CDK::R_MARKER
            inside_marker = false
          when '/'
            mask = [] of Int32
            from = encode_attribute(string, from, mask)
            attrib |= mask[0]
          when '!'
            mask = [] of Int32
            from = encode_attribute(string, from, mask)
            attrib &= ~(mask[0])
          when '#'
            # ACS character handling - simplified for now
            # Skip the ACS marker sequence
            last_char = 0
            if from + 2 < string.size
              c1 = string[from + 1]
              c2 = string[from + 2]
              case c2
              when 'L'
                case c1
                when 'L' then last_char = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_LLCORNER
                when 'U' then last_char = 'l'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_ULCORNER
                when 'H' then last_char = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_HLINE
                when 'V' then last_char = 'x'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_VLINE
                when 'P' then last_char = 'n'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_PLUS
                end
              when 'R'
                case c1
                when 'L' then last_char = 'j'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_LRCORNER
                when 'U' then last_char = 'k'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_URCORNER
                end
              when 'T'
                case c1
                when 'T' then last_char = 'w'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_TTEE
                when 'R' then last_char = 'u'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_RTEE
                when 'L' then last_char = 't'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_LTEE
                when 'B' then last_char = 'v'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 # ACS_BTEE
                end
              end

              if last_char != 0
                adjust = 1
                from += 2

                if from + 1 < string.size && string[from + 1] == '('
                  from += 2
                  adjust = 0
                  while from < string.size && string[from] != ')'
                    if string[from].ascii_number?
                      adjust = (adjust * 10) + (string[from] - '0').to_i
                    end
                    from += 1
                  end
                end

                adjust.times do
                  result << (last_char | attrib)
                  used += 1
                end
              end
            end
          end
        end
        from += 1
      end

      if result.empty?
        result << attrib
      end

      to[to.size - 1] = used
      result
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
      chtype2char(string) # simplified - just return chars for now
    end
  end
end
