require "./spec_helper"

# Helper to extract just the character from a chtype
private def char_of(chtype : Int32) : Char
  (chtype & 0xFF).chr
end

# Helper to extract just the attributes (no char, no color) from a chtype
private def attrs_of(chtype : Int32) : Int32
  chtype & ~0xFF & ~0xFF00
end

# Helper to get the display string from a chtype array
private def text_of(result : Array(Int32)) : String
  result.map { |ch| (ch & 0xFF).chr }.join
end

describe CRT::Formatter do
  describe "plain text" do
    it "converts plain text to chtype array" do
      result, len, _ = CRT::Formatter.parse("Hello")
      result.size.should eq(5)
      len.should eq(5)
      text_of(result).should eq("Hello")
    end

    it "returns empty array for empty string" do
      result, len, _ = CRT::Formatter.parse("")
      result.should be_empty
      len.should eq(0)
    end

    it "preserves character values" do
      result = CRT.fmt("ABC")
      result[0].should eq('A'.ord)
      result[1].should eq('B'.ord)
      result[2].should eq('C'.ord)
    end
  end

  describe "alignment" do
    it "defaults to left alignment" do
      _, _, align = CRT::Formatter.parse("text")
      align.should eq(CRT::LEFT)
    end

    it "detects [C] center alignment" do
      result, len, align = CRT::Formatter.parse("[C]centered")
      align.should eq(CRT::CENTER)
      len.should eq(8)
      text_of(result).should eq("centered")
    end

    it "detects [center] alignment" do
      _, _, align = CRT::Formatter.parse("[center]text")
      align.should eq(CRT::CENTER)
    end

    it "detects [R] right alignment" do
      _, _, align = CRT::Formatter.parse("[R]right")
      align.should eq(CRT::RIGHT)
    end

    it "detects [right] alignment" do
      _, _, align = CRT::Formatter.parse("[right]text")
      align.should eq(CRT::RIGHT)
    end

    it "detects [L] left alignment" do
      _, _, align = CRT::Formatter.parse("[L]left")
      align.should eq(CRT::LEFT)
    end

    it "detects [left] alignment" do
      _, _, align = CRT::Formatter.parse("[left]text")
      align.should eq(CRT::LEFT)
    end

    it "only checks alignment at string start" do
      _, _, align = CRT::Formatter.parse("hello[C]world")
      align.should eq(CRT::LEFT)
      # [C] mid-string is treated as a style tag, not alignment
    end
  end

  describe "attributes" do
    bold = LibNCurses::Attribute::Bold.value.to_i32
    underline = LibNCurses::Attribute::Underline.value.to_i32
    dim = LibNCurses::Attribute::Dim.value.to_i32
    reverse = LibNCurses::Attribute::Reverse.value.to_i32
    standout = LibNCurses::Attribute::Standout.value.to_i32
    blink = LibNCurses::Attribute::Blink.value.to_i32

    it "applies [b] bold" do
      result = CRT.fmt("[b]text")
      attrs_of(result[0]).should eq(bold)
      char_of(result[0]).should eq('t')
    end

    it "applies [bold] long form" do
      result = CRT.fmt("[bold]text")
      attrs_of(result[0]).should eq(bold)
    end

    it "applies [u] underline" do
      result = CRT.fmt("[u]text")
      attrs_of(result[0]).should eq(underline)
    end

    it "applies [underline] long form" do
      result = CRT.fmt("[underline]text")
      attrs_of(result[0]).should eq(underline)
    end

    it "applies [dim]" do
      result = CRT.fmt("[dim]text")
      attrs_of(result[0]).should eq(dim)
    end

    it "applies [rev] reverse" do
      result = CRT.fmt("[rev]text")
      attrs_of(result[0]).should eq(reverse)
    end

    it "applies [reverse] long form" do
      result = CRT.fmt("[reverse]text")
      attrs_of(result[0]).should eq(reverse)
    end

    it "applies [so] standout" do
      result = CRT.fmt("[so]text")
      attrs_of(result[0]).should eq(standout)
    end

    it "applies [standout] long form" do
      result = CRT.fmt("[standout]text")
      attrs_of(result[0]).should eq(standout)
    end

    it "applies [bk] blink" do
      result = CRT.fmt("[bk]text")
      attrs_of(result[0]).should eq(blink)
    end

    it "applies [blink] long form" do
      result = CRT.fmt("[blink]text")
      attrs_of(result[0]).should eq(blink)
    end

    it "stacks multiple attributes" do
      result = CRT.fmt("[b][u]x")
      attrs_of(result[0]).should eq(bold | underline)
    end

    it "combines attributes in one tag" do
      result = CRT.fmt("[b u]x")
      attrs_of(result[0]).should eq(bold | underline)
    end

    it "text before tag has no attributes" do
      result = CRT.fmt("plain[b]bold")
      attrs_of(result[0]).should eq(0)  # 'p'
      attrs_of(result[4]).should eq(0)  # 'n'
      attrs_of(result[5]).should eq(bold)  # 'b' in "bold"
    end
  end

  describe "style stack" do
    bold = LibNCurses::Attribute::Bold.value.to_i32
    underline = LibNCurses::Attribute::Underline.value.to_i32

    it "pops last style with [/]" do
      result = CRT.fmt("[b]bold[/]plain")
      attrs_of(result[0]).should eq(bold)   # 'b' in "bold"
      attrs_of(result[3]).should eq(bold)   # 'd' in "bold"
      attrs_of(result[4]).should eq(0)      # 'p' in "plain"
    end

    it "pops nested styles correctly" do
      result = CRT.fmt("[b]B[u]BU[/]B[/]plain")
      # 'B' — bold only
      attrs_of(result[0]).should eq(bold)
      # 'B' in "BU" — bold + underline
      attrs_of(result[1]).should eq(bold | underline)
      # 'U' in "BU" — bold + underline
      attrs_of(result[2]).should eq(bold | underline)
      # 'B' after [/] — bold only (underline popped)
      attrs_of(result[3]).should eq(bold)
      # 'p' after [/] — no attributes
      attrs_of(result[4]).should eq(0)
    end

    it "resets all with [//]" do
      result = CRT.fmt("[b][u]styled[//]plain")
      attrs_of(result[0]).should eq(bold | underline)
      # "plain" starts at index 6
      attrs_of(result[6]).should eq(0)
    end

    it "pop on empty stack is a no-op" do
      result = CRT.fmt("[/]text")
      attrs_of(result[0]).should eq(0)
      text_of(result).should eq("text")
    end
  end

  describe "escape sequences" do
    it "treats \\[ as literal bracket" do
      result, len, _ = CRT::Formatter.parse("a\\[b")
      len.should eq(3)
      text_of(result).should eq("a[b")
    end

    it "handles unclosed bracket as literal" do
      result = CRT.fmt("hello[world")
      text_of(result).should eq("hello[world")
    end
  end

  describe "tabs" do
    it "expands tab to 8-column boundary" do
      result, len, _ = CRT::Formatter.parse("\t")
      len.should eq(8)
      result.all? { |ch| char_of(ch) == ' ' }.should be_true
    end

    it "expands tab after text to next boundary" do
      _, len, _ = CRT::Formatter.parse("ab\t")
      len.should eq(8)  # 'a','b' + 6 spaces to reach column 8
    end
  end

  describe "color notation" do
    # Color pair allocation requires ncurses, so we test the token parsing
    # logic by checking that parse_tokens extracts the correct fg/bg values.

    it "parses #XX as fg only" do
      fg, bg = CRT::Formatter.parse_color_token("#0F")
      fg.should eq(0x0F)
      bg.should eq(-1)
    end

    it "parses ##XX as bg only" do
      fg, bg = CRT::Formatter.parse_color_token("##B0")
      fg.should eq(-1)
      bg.should eq(0xB0)
    end

    it "parses #XX/YY as fg/bg" do
      fg, bg = CRT::Formatter.parse_color_token("#0F/B0")
      fg.should eq(0x0F)
      bg.should eq(0xB0)
    end

    it "parses ##YY/XX as bg/fg" do
      fg, bg = CRT::Formatter.parse_color_token("##B0/0F")
      fg.should eq(0x0F)
      bg.should eq(0xB0)
    end

    it "handles full range hex values" do
      fg, bg = CRT::Formatter.parse_color_token("#FF/00")
      fg.should eq(0xFF)
      bg.should eq(0x00)
    end
  end

  describe "named styles" do
    it "expands a registered style" do
      bold = LibNCurses::Attribute::Bold.value.to_i32
      underline = LibNCurses::Attribute::Underline.value.to_i32

      CRT.style("fancy", "bold u")
      result = CRT.fmt("[fancy]text[/]after")
      attrs_of(result[0]).should eq(bold | underline)
      attrs_of(result[4]).should eq(0)  # 'a' in "after"
    ensure
      CRT.styles.delete("fancy")
    end

    it "unknown single-token tag produces no attributes" do
      result = CRT.fmt("[unknown]text")
      attrs_of(result[0]).should eq(0)
      text_of(result).should eq("text")
    end
  end

  describe "CRT.fmt convenience" do
    it "returns chtype array directly" do
      result = CRT.fmt("hello")
      result.size.should eq(5)
      text_of(result).should eq("hello")
    end
  end
end
