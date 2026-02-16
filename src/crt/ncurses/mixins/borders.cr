module CRT
  module Borders
    property box : Bool = false
    property ul_char : Int32 = 'l'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property ur_char : Int32 = 'k'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property ll_char : Int32 = 'm'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property lr_char : Int32 = 'j'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property hz_char : Int32 = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property vt_char : Int32 = 'x'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    property bx_attr : Int32 = 0

    getter border_size : Int32 = 0
    getter framing : CRT::Framing? = nil

    def init_borders
      @ul_char = 'l'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @ur_char = 'k'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @ll_char = 'm'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @lr_char = 'j'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @hz_char = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @vt_char = 'x'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @bx_attr = 0
    end

    def set_box(box : Bool | CRT::Framing | Nil)
      case box
      when CRT::Framing
        @framing = box
        @box = false
        @border_size = 1
      when true
        @framing = nil
        @box = true
        @border_size = 1
      else
        @framing = nil
        @box = false
        @border_size = 0
      end
    end

    def register_framing
      if (framing = @framing) && (w = @win)
        x = LibNCurses.getbegx(w).to_i32
        y = LibNCurses.getbegy(w).to_i32
        framing.add(x: x, y: y, h: @box_width, v: @box_height)
      end
    end

    def unregister_framing
      if (framing = @framing) && (w = @win)
        x = LibNCurses.getbegx(w).to_i32
        y = LibNCurses.getbegy(w).to_i32
        framing.remove(x: x, y: y, h: @box_width, v: @box_height)
        @framing = nil
      end
    end
  end
end
