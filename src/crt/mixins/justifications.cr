module CRT
  module Justifications
    # Returns the adjustment needed to fill the justification requirement
    # for a string within a box of given width.
    def justify_string(box_width : Int32, mesg_length : Int32, justify : Int32) : Int32
      return 0 if mesg_length >= box_width

      case justify
      when CRT::LEFT
        0
      when CRT::RIGHT
        box_width - mesg_length
      when CRT::CENTER
        (box_width - mesg_length) // 2
      else
        justify
      end
    end
  end
end
