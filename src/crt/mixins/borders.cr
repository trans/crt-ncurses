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

    def init_borders
      @ul_char = 'l'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @ur_char = 'k'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @ll_char = 'm'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @lr_char = 'j'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @hz_char = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @vt_char = 'x'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
      @bx_attr = 0
    end

    def set_box(box : Bool)
      @box = box
      @border_size = box ? 1 : 0
    end
  end
end
