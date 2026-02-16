module CRT::Ncurses
  abstract class Scroller < CRT::Ncurses::CRTObjs
    getter current_item : Int32 = 0
    getter current_top : Int32 = 0
    getter current_high : Int32 = 0
    getter list_size : Int32 = 0
    getter view_size : Int32 = 0
    getter max_top_item : Int32 = 0
    getter last_item : Int32 = 0
    getter left_char : Int32 = 0
    getter max_left_char : Int32 = 0
    getter step : Float64 = 1.0
    getter toggle_size : Int32 = 1

    def initialize
      super
    end

    def key_up
      if @list_size > 0
        if @current_item > 0
          if @current_high == 0
            if @current_top != 0
              @current_top -= 1
              @current_item -= 1
            else
              CRT::Ncurses.beep
            end
          else
            @current_item -= 1
            @current_high -= 1
          end
        else
          CRT::Ncurses.beep
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_down
      if @list_size > 0
        if @current_item < @list_size - 1
          if @current_high == @view_size - 1
            if @current_top < @max_top_item
              @current_top += 1
              @current_item += 1
            else
              CRT::Ncurses.beep
            end
          else
            @current_item += 1
            @current_high += 1
          end
        else
          CRT::Ncurses.beep
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_left
      if @list_size > 0
        if @left_char == 0
          CRT::Ncurses.beep
        else
          @left_char -= 1
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_right
      if @list_size > 0
        if @left_char >= @max_left_char
          CRT::Ncurses.beep
        else
          @left_char += 1
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_ppage
      if @list_size > 0
        if @current_top > 0
          if @current_top >= @view_size - 1
            @current_top -= @view_size - 1
            @current_item -= @view_size - 1
          else
            key_home
          end
        else
          CRT::Ncurses.beep
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_npage
      if @list_size > 0
        if @current_top < @max_top_item
          if @current_top + @view_size - 1 <= @max_top_item
            @current_top += @view_size - 1
            @current_item += @view_size - 1
          else
            @current_top = @max_top_item
            @current_item = @last_item
            @current_high = @view_size - 1
          end
        else
          CRT::Ncurses.beep
        end
      else
        CRT::Ncurses.beep
      end
    end

    def key_home
      @current_top = 0
      @current_item = 0
      @current_high = 0
    end

    def key_end
      if @max_top_item == -1
        @current_top = 0
        @current_item = @last_item - 1
      else
        @current_top = @max_top_item
        @current_item = @last_item
      end
      @current_high = @view_size - 1
    end

    def max_view_size : Int32
      @box_height - (2 * @border_size + @title_lines)
    end

    # Set variables that depend upon the list_size
    def set_view_size(list_size : Int32)
      @view_size = max_view_size
      @list_size = list_size
      @last_item = list_size - 1
      @max_top_item = list_size - @view_size

      if list_size < @view_size
        @view_size = list_size
        @max_top_item = 0
      end

      if @list_size > 0 && max_view_size > 0
        @step = 1.0 * max_view_size / @list_size
        @toggle_size = if @list_size > max_view_size
                        1
                       else
                        @step.ceil.to_i32
                       end
      else
        @step = 1.0
        @toggle_size = 1
      end
    end

    def set_position(item : Int32)
      if item <= 0
        key_home
      elsif item > @list_size - 1
        @current_top = @max_top_item
        @current_item = @list_size - 1
        @current_high = @view_size - 1
      elsif item >= @current_top && item < @current_top + @view_size
        @current_item = item
        @current_high = item - @current_top
      else
        @current_top = item - (@view_size - 1)
        @current_item = item
        @current_high = @view_size - 1
      end
    end

    def current_item=(item : Int32)
      set_position(item)
    end
  end
end
