module CDK
  module Justifications
    # Returns the adjustment needed to fill the justification requirement
    # for a string within a box of given width.
    def justify_string(box_width : Int32, mesg_length : Int32, justify : Int32) : Int32
      return 0 if mesg_length >= box_width

      case justify
      when CDK::LEFT
        0
      when CDK::RIGHT
        box_width - mesg_length
      when CDK::CENTER
        (box_width - mesg_length) // 2
      else
        justify
      end
    end
  end
end
