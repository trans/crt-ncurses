require "./spec_helper"

# Lightweight test harness that includes mixins without needing ncurses.
private class MixinHost
  include CRT::Ncurses::Bindings
  include CRT::Ncurses::Converters
  include CRT::Ncurses::ExitConditions
  include CRT::Ncurses::Justifications

  def initialize
    @exit_type = CRT::Ncurses::ExitType::NEVER_ACTIVATED
  end
end

describe CRT do
  it "has a version" do
    CRT::Ncurses::VERSION.should eq("0.6.1")
  end

  describe "constants" do
    it "defines position constants" do
      CRT::Ncurses::LEFT.should eq(9000)
      CRT::Ncurses::RIGHT.should eq(9001)
      CRT::Ncurses::CENTER.should eq(9002)
      CRT::Ncurses::TOP.should eq(9003)
      CRT::Ncurses::BOTTOM.should eq(9004)
    end

    it "defines direction enum" do
      CRT::Ncurses::HORIZONTAL.should eq(CRT::Ncurses::Direction::Horizontal)
      CRT::Ncurses::VERTICAL.should eq(CRT::Ncurses::Direction::Vertical)
    end

    it "defines position enum" do
      CRT::Ncurses::Position::Left.value.should eq(9000)
      CRT::Ncurses::Position::Right.value.should eq(9001)
      CRT::Ncurses::Position::Center.value.should eq(9002)
      CRT::Ncurses::Position::Top.value.should eq(9003)
      CRT::Ncurses::Position::Bottom.value.should eq(9004)
      CRT::Ncurses::Position::Full.value.should eq(9007)
    end

    it "defines dominant enum" do
      CRT::Ncurses::Dominant::None.value.should eq(0)
      CRT::Ncurses::Dominant::Row.value.should eq(1)
      CRT::Ncurses::Dominant::Col.value.should eq(2)
    end

    it "defines key constants" do
      CRT::Ncurses::KEY_ESC.should eq(27)
      CRT::Ncurses::KEY_TAB.should eq(9)
      CRT::Ncurses::KEY_RETURN.should eq(10)
    end

    it "computes ctrl keys" do
      CRT::Ncurses.ctrl('L').should eq(12)
      CRT::Ncurses.ctrl('A').should eq(1)
    end
  end

  describe "helper types" do
    it "checks digit characters" do
      CRT::Ncurses.digit?('5').should be_true
      CRT::Ncurses.digit?('a').should be_false
    end

    it "checks alpha characters" do
      CRT::Ncurses.alpha?('a').should be_true
      CRT::Ncurses.alpha?('5').should be_false
    end

    it "checks is_char? for printable vs function keys" do
      CRT::Ncurses.is_char?('a'.ord).should be_true
      CRT::Ncurses.is_char?(0).should be_true
      CRT::Ncurses.is_char?(-1).should be_false
      CRT::Ncurses.is_char?(LibNCurses::Key::Down.value).should be_false
    end
  end

  describe "set_widget_dimension" do
    it "returns parent dim for FULL" do
      CRT::Ncurses.set_widget_dimension(80, CRT::Ncurses::FULL, 0).should eq(80)
    end

    it "returns parent dim for zero" do
      CRT::Ncurses.set_widget_dimension(80, 0, 0).should eq(80)
    end

    it "returns proposed dim for positive value" do
      CRT::Ncurses.set_widget_dimension(80, 40, 0).should eq(40)
    end

    it "clamps to parent for oversized value" do
      CRT::Ncurses.set_widget_dimension(80, 100, 0).should eq(80)
    end

    it "handles negative dimension" do
      CRT::Ncurses.set_widget_dimension(80, -10, 0).should eq(70)
    end
  end

  describe CRT::Ncurses::Bindings do
    it "remaps keys via remap_key" do
      host = MixinHost.new
      host.remap_key('g'.ord, LibNCurses::Key::Home.value)
      host.resolve_key('g'.ord).should eq(LibNCurses::Key::Home.value)
    end

    it "returns original key when no remap exists" do
      host = MixinHost.new
      host.resolve_key('x'.ord).should eq('x'.ord)
    end

    it "accepts Char overload for remap_key" do
      host = MixinHost.new
      host.remap_key('G', LibNCurses::Key::End.value)
      host.resolve_key('G'.ord).should eq(LibNCurses::Key::End.value)
    end

    it "calls on_key handler and consumes by default" do
      host = MixinHost.new
      called = false
      host.on_key('q'.ord) { called = true; nil }
      host.resolve_key('q'.ord).should be_nil
      called.should be_true
    end

    it "accepts Char overload for on_key" do
      host = MixinHost.new
      called = false
      host.on_key('q') { called = true; nil }
      host.resolve_key('q'.ord).should be_nil
      called.should be_true
    end

    it "passes through when on_key handler returns key code" do
      host = MixinHost.new
      host.on_key('q'.ord) { 'q'.ord }
      host.resolve_key('q'.ord).should eq('q'.ord)
    end

    it "allows dynamic remapping via on_key return value" do
      host = MixinHost.new
      host.on_key('j'.ord) { LibNCurses::Key::Down.value }
      host.resolve_key('j'.ord).should eq(LibNCurses::Key::Down.value)
    end

    it "prioritizes on_key handler over remap" do
      host = MixinHost.new
      host.remap_key('g'.ord, LibNCurses::Key::Home.value)
      host.on_key('g'.ord) { nil }
      host.resolve_key('g'.ord).should be_nil
    end

    it "removes bindings with unbind_key" do
      host = MixinHost.new
      host.remap_key('g'.ord, LibNCurses::Key::Home.value)
      host.on_key('x'.ord) { }
      host.unbind_key('g'.ord)
      host.unbind_key('x'.ord)
      host.resolve_key('g'.ord).should eq('g'.ord)
      host.resolve_key('x'.ord).should eq('x'.ord)
    end

    it "clears all bindings with clear_key_bindings" do
      host = MixinHost.new
      host.remap_key('a'.ord, 1)
      host.remap_key('b'.ord, 2)
      host.on_key('c'.ord) { }
      host.clear_key_bindings
      host.key_remaps.should be_empty
      host.key_handlers.should be_empty
    end
  end

  describe CRT::Ncurses::Converters do
    host = MixinHost.new

    describe "char2chtype" do
      it "converts plain text to chtype array" do
        result, len, align = host.char2chtype("Hello")
        result.size.should eq(5)
        len.should eq(5)
        align.should eq(CRT::Ncurses::LEFT)
        # Each chtype should be the char ord with no attributes
        result[0].should eq('H'.ord)
        result[4].should eq('o'.ord)
      end

      it "returns empty array for empty string" do
        result, _, _ = host.char2chtype("")
        result.should be_empty
      end

      it "detects [C] center alignment" do
        _, len, align = host.char2chtype("[C]centered")
        align.should eq(CRT::Ncurses::CENTER)
        len.should eq(8)
      end

      it "detects [R] right alignment" do
        _, len, align = host.char2chtype("[R]right")
        align.should eq(CRT::Ncurses::RIGHT)
        len.should eq(5)
      end

      it "detects [L] left alignment" do
        _, len, align = host.char2chtype("[L]left")
        align.should eq(CRT::Ncurses::LEFT)
        len.should eq(4)
      end

      it "applies bold attribute" do
        result, len, _ = host.char2chtype("[b]bold")
        bold = LibNCurses::Attribute::Bold.value.to_i32
        len.should eq(4)
        result[0].should eq('b'.ord | bold)
        result[3].should eq('d'.ord | bold)
      end

      it "pops attribute with [/]" do
        result, len, _ = host.char2chtype("[b]on[/]off")
        bold = LibNCurses::Attribute::Bold.value.to_i32
        len.should eq(5)
        # "on" has bold
        result[0].should eq('o'.ord | bold)
        result[1].should eq('n'.ord | bold)
        # "off" has no bold
        result[2].should eq('o'.ord)
        result[4].should eq('f'.ord)
      end

      it "handles escaped bracket" do
        result, len, _ = host.char2chtype("a\\[b")
        len.should eq(3)
        result[0].should eq('a'.ord)
        result[1].should eq('['.ord)
        result[2].should eq('b'.ord)
      end

      it "expands tabs to 8-column boundaries" do
        result, len, _ = host.char2chtype("\t")
        len.should eq(8)
        result.all? { |ch| ch == ' '.ord }.should be_true
      end

      it "stacks multiple attributes" do
        result, len, _ = host.char2chtype("[b][u]x")
        bold = LibNCurses::Attribute::Bold.value.to_i32
        underline = LibNCurses::Attribute::Underline.value.to_i32
        len.should eq(1)
        result[0].should eq('x'.ord | bold | underline)
      end
    end

    describe "char_of" do
      it "extracts character from chtype" do
        bold = LibNCurses::Attribute::Bold.value.to_i32
        host.char_of('A'.ord | bold).should eq('A')
      end
    end

    describe "chtype2char" do
      it "converts chtype array back to string" do
        bold = LibNCurses::Attribute::Bold.value.to_i32
        arr = ['H'.ord | bold, 'i'.ord]
        host.chtype2char(arr).should eq("Hi")
      end
    end
  end

  describe CRT::Ncurses::Display do
    it "identifies hidden display types" do
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::HCHAR).should be_true
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::HINT).should be_true
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::HMIXED).should be_true
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::CHAR).should be_false
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::INT).should be_false
      CRT::Ncurses::Display.hidden_display_type?(CRT::Ncurses::DisplayType::MIXED).should be_false
    end

    describe "filter_by_display_type" do
      it "passes any character for MIXED type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::MIXED, 'a'.ord).should eq('a'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::MIXED, '5'.ord).should eq('5'.ord)
      end

      it "allows only digits for INT type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::INT, '5'.ord).should eq('5'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::INT, 'a'.ord).should eq(-1)
      end

      it "allows only letters for CHAR type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::CHAR, 'a'.ord).should eq('a'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::CHAR, '5'.ord).should eq(-1)
      end

      it "forces uppercase for UCHAR type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::UCHAR, 'a'.ord).should eq('A'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::UCHAR, '5'.ord).should eq(-1)
      end

      it "forces lowercase for LCHAR type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::LCHAR, 'A'.ord).should eq('a'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::LCHAR, '5'.ord).should eq(-1)
      end

      it "forces uppercase for UMIXED type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::UMIXED, 'a'.ord).should eq('A'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::UMIXED, '5'.ord).should eq('5'.ord)
      end

      it "forces lowercase for LMIXED type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::LMIXED, 'A'.ord).should eq('a'.ord)
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::LMIXED, '5'.ord).should eq('5'.ord)
      end

      it "rejects all input for VIEWONLY type" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::VIEWONLY, 'a'.ord).should eq(-1)
      end

      it "rejects function keys" do
        CRT::Ncurses::Display.filter_by_display_type(CRT::Ncurses::DisplayType::MIXED, LibNCurses::Key::Down.value).should eq(-1)
      end
    end
  end

  describe CRT::Ncurses::Justifications do
    host = MixinHost.new

    it "left-justifies (no offset)" do
      host.justify_string(40, 10, CRT::Ncurses::LEFT).should eq(0)
    end

    it "right-justifies" do
      host.justify_string(40, 10, CRT::Ncurses::RIGHT).should eq(30)
    end

    it "center-justifies" do
      host.justify_string(40, 10, CRT::Ncurses::CENTER).should eq(15)
    end

    it "returns 0 when message fills the box" do
      host.justify_string(10, 10, CRT::Ncurses::CENTER).should eq(0)
    end

    it "returns 0 when message exceeds box" do
      host.justify_string(5, 10, CRT::Ncurses::RIGHT).should eq(0)
    end

    it "passes through numeric justify values" do
      host.justify_string(40, 10, 5).should eq(5)
    end
  end

  describe CRT::Ncurses::ExitConditions do
    it "starts as NEVER_ACTIVATED" do
      host = MixinHost.new
      host.exit_type.should eq(CRT::Ncurses::ExitType::NEVER_ACTIVATED)
    end

    it "sets ESCAPE_HIT for ESC key" do
      host = MixinHost.new
      host.set_exit_type(CRT::Ncurses::KEY_ESC)
      host.exit_type.should eq(CRT::Ncurses::ExitType::ESCAPE_HIT)
    end

    it "sets NORMAL for RETURN key" do
      host = MixinHost.new
      host.set_exit_type(CRT::Ncurses::KEY_RETURN)
      host.exit_type.should eq(CRT::Ncurses::ExitType::NORMAL)
    end

    it "sets NORMAL for TAB key" do
      host = MixinHost.new
      host.set_exit_type(CRT::Ncurses::KEY_TAB)
      host.exit_type.should eq(CRT::Ncurses::ExitType::NORMAL)
    end

    it "sets EARLY_EXIT for 0" do
      host = MixinHost.new
      host.set_exit_type(0)
      host.exit_type.should eq(CRT::Ncurses::ExitType::EARLY_EXIT)
    end

    it "resets to NEVER_ACTIVATED" do
      host = MixinHost.new
      host.set_exit_type(CRT::Ncurses::KEY_ESC)
      host.reset_exit_type
      host.exit_type.should eq(CRT::Ncurses::ExitType::NEVER_ACTIVATED)
    end
  end
end
