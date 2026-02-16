module CRT
  module Alignments
    # Realigns x and y positions based on alignment constants
    # (CENTER, LEFT, RIGHT, TOP, BOTTOM) relative to the given window.
    def alignxy(window : NCurses::Window, xpos : Int32, ypos : Int32,
                box_width : Int32, box_height : Int32) : {Int32, Int32}
      first = 0
      last = window.max_x
      gap = {last - box_width, 0}.max
      last = first + gap

      x = case xpos
          when CRT::LEFT   then first
          when CRT::RIGHT  then first + gap
          when CRT::CENTER then first + (gap // 2)
          else                  xpos.clamp(first, last)
          end

      first = 0
      last = window.max_y
      gap = {last - box_height, 0}.max
      last = first + gap

      y = case ypos
          when CRT::TOP    then first
          when CRT::BOTTOM then first + gap
          when CRT::CENTER then first + (gap // 2)
          else                  ypos.clamp(first, last)
          end

      {x, y}
    end
  end
end
