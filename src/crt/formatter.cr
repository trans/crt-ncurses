module CRT
  # On-demand color pair allocation for 256-color support.
  # Pairs are allocated as needed rather than pre-allocated.
  @@color_pairs = {} of {Int32, Int32} => Int32
  @@next_pair : Int32 = 1
  @@colors_ready : Bool = false

  # Initialize color support (called once, lazily)
  def self.init_colors
    return if @@colors_ready
    if NCurses.has_colors?
      NCurses.start_color
      NCurses.use_default_colors
      @@colors_ready = true
    end
  end

  # Allocate or retrieve a color pair for the given fg/bg combination.
  # Colors are 0-255 (terminal palette indices), or -1 for terminal default.
  # Returns the chtype bits for the pair (pair_number << 8).
  def self.color_pair(fg : Int32, bg : Int32) : Int32
    init_colors
    return 0 unless @@colors_ready

    key = {fg, bg}
    if pair = @@color_pairs[key]?
      pair << 8
    else
      pair = @@next_pair
      @@next_pair += 1
      LibNCurses.init_pair(pair.to_i16, fg.to_i16, bg.to_i16)
      @@color_pairs[key] = pair
      pair << 8
    end
  end

  # Build a chtype suitable for background= (space char + color pair + attributes).
  #
  #   CRT.color(7, 4)          # white on blue
  #   CRT.color("#07/04")      # same, hex notation
  #   CRT.color("bold #07/04") # bold white on blue
  #
  def self.color(fg : Int32, bg : Int32, fill : Char = ' ') : Int32
    fill.ord | color_pair(fg, bg)
  end

  def self.color(spec : String, fill : Char = ' ') : Int32
    attrs = 0
    fg = -1
    bg = -1
    spec.split.each do |token|
      if attr = Formatter::ATTRIBUTES[token]?
        attrs |= attr.value.to_i32
      elsif token.starts_with?('#')
        tfg, tbg = Formatter.parse_color_token(token)
        fg = tfg if tfg != -1
        bg = tbg if tbg != -1
      end
    end
    fill.ord | attrs | color_pair(fg, bg)
  end

  # Style registry — named styles that expand in format strings.
  # Register: CRT.style("error", "bold #FF ##00")
  # Use:      CRT.fmt("[error]Oops![/]")
  @@styles = {} of String => String

  def self.style(name : String, definition : String)
    @@styles[name] = definition
  end

  def self.styles : Hash(String, String)
    @@styles
  end

  # Format a BBCode-style string into a chtype array.
  #
  #   CRT.fmt("[bold #0F]Hello[/] world")
  #
  # Returns an Array(Int32) of chtype values ready for Draw.write_chtype.
  def self.fmt(string : String) : Array(Int32)
    result, _, _ = Formatter.parse(string)
    result
  end

  module Formatter
    # Built-in attribute names (short and long forms)
    ATTRIBUTES = {
      "b"         => LibNCurses::Attribute::Bold,
      "bold"      => LibNCurses::Attribute::Bold,
      "u"         => LibNCurses::Attribute::Underline,
      "underline" => LibNCurses::Attribute::Underline,
      "dim"       => LibNCurses::Attribute::Dim,
      "rev"       => LibNCurses::Attribute::Reverse,
      "reverse"   => LibNCurses::Attribute::Reverse,
      "so"        => LibNCurses::Attribute::Standout,
      "standout"  => LibNCurses::Attribute::Standout,
      "bk"        => LibNCurses::Attribute::Blink,
      "blink"     => LibNCurses::Attribute::Blink,
    }

    # Alignment tag names
    ALIGNMENTS = {
      "C"      => CRT::CENTER,
      "center" => CRT::CENTER,
      "R"      => CRT::RIGHT,
      "right"  => CRT::RIGHT,
      "L"      => CRT::LEFT,
      "left"   => CRT::LEFT,
    }

    # A frame on the style stack, recording what was pushed so it can be popped.
    record StyleFrame, attrs : Int32, fg : Int32, bg : Int32

    # Parse a BBCode-style format string into a chtype array.
    #
    # Syntax:
    #   [b] or [bold]       — bold on
    #   [u] or [underline]  — underline on
    #   [dim]               — dim on
    #   [rev] or [reverse]  — reverse on
    #   [so] or [standout]  — standout on
    #   [bk] or [blink]     — blink on
    #   [#FF]               — foreground color (hex 00-FF)
    #   [##B0]              — background color (hex 00-FF)
    #   [b #FF ##00]        — combined attributes and colors
    #   [/]                 — pop last style
    #   [//]                — reset all styles
    #   [stylename]         — apply registered style
    #   \[                  — literal open bracket
    #   [C] or [center]     — center alignment (at string start only)
    #   [R] or [right]      — right alignment (at string start only)
    #   [L] or [left]       — left alignment (at string start only)
    #
    def self.parse(string : String) : {Array(Int32), Int32, Int32}
      result = [] of Int32

      return {result, 0, CRT::LEFT} if string.empty?

      alignment = CRT::LEFT

      stack = [] of StyleFrame
      current_attrs = 0
      current_fg = -1
      current_bg = -1

      start = 0
      used = 0

      # Check for alignment tag at the very start
      if string[0]? == '['
        close = string.index(']', 1)
        if close
          tag = string[1...close]
          if align_val = ALIGNMENTS[tag]?
            alignment = align_val
            start = close + 1
          end
        end
      end

      from = start
      while from < string.size
        if string[from] == '\\' && from + 1 < string.size && string[from + 1] == '['
          # Escaped bracket — literal [
          from += 1
          result << compute_chtype('['.ord, current_attrs, current_fg, current_bg)
          used += 1
        elsif string[from] == '['
          # Look for closing bracket
          close = string.index(']', from + 1)
          if close
            tag_content = string[from + 1...close]

            if tag_content == "/"
              # Pop last style frame
              if frame = stack.pop?
                current_attrs &= ~frame.attrs
                current_fg = find_prev_color(stack, :fg) if frame.fg != -1
                current_bg = find_prev_color(stack, :bg) if frame.bg != -1
              end
            elsif tag_content == "//"
              # Reset all styles
              stack.clear
              current_attrs = 0
              current_fg = -1
              current_bg = -1
            else
              # Parse as attribute/color/style tag
              tokens = tokenize(tag_content)
              frame_attrs, frame_fg, frame_bg = parse_tokens(tokens)

              stack << StyleFrame.new(frame_attrs, frame_fg, frame_bg)
              current_attrs |= frame_attrs
              current_fg = frame_fg if frame_fg != -1
              current_bg = frame_bg if frame_bg != -1
            end

            from = close
          else
            # No closing bracket — treat [ as literal
            result << compute_chtype('['.ord, current_attrs, current_fg, current_bg)
            used += 1
          end
        elsif string[from] == '\t'
          # Expand tab to 8-column boundary
          loop do
            result << compute_chtype(' '.ord, current_attrs, current_fg, current_bg)
            used += 1
            break unless (used & 7) != 0
          end
        else
          result << compute_chtype(string[from].ord, current_attrs, current_fg, current_bg)
          used += 1
        end

        from += 1
      end

      {result, used, alignment}
    end

    # Tokenize a tag's content, expanding registered styles.
    private def self.tokenize(tag_content : String) : Array(String)
      tokens = tag_content.split

      # If single token that's not a built-in, check the style registry
      if tokens.size == 1 && !ATTRIBUTES.has_key?(tokens[0]) && !tokens[0].starts_with?('#')
        if style_def = CRT.styles[tokens[0]]?
          return style_def.split
        end
      end

      tokens
    end

    # Parse a single color token and return {fg, bg}.
    # Used by parse_tokens internally and exposed for testing.
    #
    # Color notation:
    #   #XX        — foreground only
    #   ##XX       — background only
    #   #XX/YY     — foreground XX, background YY
    #   ##YY/XX    — background YY, foreground XX
    #
    # TODO: Support basic color words, e.g. #red, #red/blue, ##blue/red.
    def self.parse_color_token(token : String) : {Int32, Int32}
      fg = -1
      bg = -1

      if token.starts_with?("##")
        rest = token[2..]
        if (slash = rest.index('/'))
          bg = rest[0...slash].to_i(16) rescue -1
          fg = rest[slash + 1..].to_i(16) rescue -1
        else
          bg = rest.to_i(16) rescue -1
        end
      elsif token.starts_with?('#')
        rest = token[1..]
        if (slash = rest.index('/'))
          fg = rest[0...slash].to_i(16) rescue -1
          bg = rest[slash + 1..].to_i(16) rescue -1
        else
          fg = rest.to_i(16) rescue -1
        end
      end

      {fg, bg}
    end

    # Parse tokens into attribute bits and color values.
    #
    # TODO: Support basic color words, e.g. #red, #red/blue, ##blue//red.
    private def self.parse_tokens(tokens : Array(String)) : {Int32, Int32, Int32}
      frame_attrs = 0
      frame_fg = -1
      frame_bg = -1

      tokens.each do |token|
        if attr = ATTRIBUTES[token]?
          frame_attrs |= attr.value.to_i32
        elsif token.starts_with?('#')
          tfg, tbg = parse_color_token(token)
          frame_fg = tfg if tfg != -1
          frame_bg = tbg if tbg != -1
        end
      end

      {frame_attrs, frame_fg, frame_bg}
    end

    # Compute the chtype for a character with current attributes and colors.
    private def self.compute_chtype(char_ord : Int32, attrs : Int32, fg : Int32, bg : Int32) : Int32
      chtype = char_ord | attrs
      if fg != -1 || bg != -1
        chtype |= CRT.color_pair(fg, bg)
      end
      chtype
    end

    # Walk the stack backwards to find the most recent color for a given channel.
    private def self.find_prev_color(stack : Array(StyleFrame), which : Symbol) : Int32
      stack.reverse_each do |frame|
        if which == :fg && frame.fg != -1
          return frame.fg
        elsif which == :bg && frame.bg != -1
          return frame.bg
        end
      end
      -1
    end
  end
end
