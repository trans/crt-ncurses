module CRT
  module Alignments
    # Realigns x and y positions based on alignment constants
    # (CENTER, LEFT, RIGHT, TOP, BOTTOM) relative to the given window.
    def alignxy(window : NCurses::Window, xpos : Array(Int32), ypos : Array(Int32),
                box_width : Int32, box_height : Int32)
      first = 0
      last = window.max_x
      gap = last - box_width
      gap = 0 if gap < 0
      last = first + gap

      case xpos[0]
      when CRT::LEFT
        xpos[0] = first
      when CRT::RIGHT
        xpos[0] = first + gap
      when CRT::CENTER
        xpos[0] = first + (gap // 2)
      else
        if xpos[0] > last
          xpos[0] = last
        elsif xpos[0] < first
          xpos[0] = first
        end
      end

      first = 0
      last = window.max_y
      gap = last - box_height
      gap = 0 if gap < 0
      last = first + gap

      case ypos[0]
      when CRT::TOP
        ypos[0] = first
      when CRT::BOTTOM
        ypos[0] = first + gap
      when CRT::CENTER
        ypos[0] = first + (gap // 2)
      else
        if ypos[0] > last
          ypos[0] = last
        elsif ypos[0] < first
          ypos[0] = first
        end
      end
    end
  end
end
