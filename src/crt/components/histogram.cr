module CRT
  class Histogram < CRT::CRTObjs
    property orient : Int32 = CRT::HORIZONTAL
    property filler : Int32 = '#'.ord | LibNCurses::Attribute::Reverse.value.to_i32
    property stats_attr : Int32 = 0
    property stats_pos : Int32 = CRT::TOP
    property view_type : CRT::HistViewType = CRT::HistViewType::REAL
    property value : Int32 = 0
    property low : Int32 = 0
    property high : Int32 = 0
    property parent : NCurses::Window? = nil

    @field_width : Int32 = 0
    @field_height : Int32 = 0
    @bar_size : Int32 = 0
    @percent : Float64 = 0.0
    @shadow : Bool = false

    @low_string : String = ""
    @high_string : String = ""
    @cur_string : String = ""
    @lowx : Int32 = 0
    @lowy : Int32 = 0
    @highx : Int32 = 0
    @highy : Int32 = 0
    @curx : Int32 = 0
    @cury : Int32 = 0

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, orient : Int32 = CRT::HORIZONTAL,
                   title : String = "", box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 2)
      old_height = box_height

      box_width = CRT.set_widget_dimension(parent_width, width, 0)
      old_width = box_width

      box_width = set_title(title, -(box_width + 1))

      box_height += @title_lines

      # Don't extend beyond parent
      box_width = box_width > parent_width ? old_width : box_width
      box_height = box_height > parent_height ? old_height : box_height

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @screen = cdkscreen
      @parent = parent_window
      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = box_width - 2 * @border_size
      @field_height = box_height - @title_lines - 2 * @border_size
      @orient = orient
      @shadow = shadow

      @filler = '#'.ord | LibNCurses::Attribute::Reverse.value.to_i32
      @stats_attr = 0
      @stats_pos = CRT::TOP
      @view_type = CRT::HistViewType::REAL

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      cdkscreen.register(:HISTOGRAM, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)
      0
    end

    def set(view_type : CRT::HistViewType, stats_pos : Int32, stats_attr : Int32,
            low : Int32, high : Int32, value : Int32, filler : Int32, box : Bool)
      set_display_type(view_type)
      set_stats_pos(stats_pos)
      set_value(low, high, value)
      set_filler_char(filler)
      set_stats_attr(stats_attr)
      set_box(box)
    end

    def set_value(low : Int32, high : Int32, value : Int32)
      @low = low <= high ? low : 0
      @high = low <= high ? high : 0
      @value = (low <= value && value <= high) ? value : 0
      @percent = @high == 0 ? 0.0 : 1.0 * @value / @high

      # Determine bar size
      if @orient == CRT::VERTICAL
        @bar_size = (@percent * @field_height).to_i32
      else
        @bar_size = (@percent * @field_width).to_i32
      end

      # Set label strings based on view_type and orientation
      return if @view_type == CRT::HistViewType::NONE

      if @orient == CRT::VERTICAL
        set_vertical_labels
      else
        set_horizontal_labels
      end
    end

    def get_value : Int32
      @value
    end

    def get_low_value : Int32
      @low
    end

    def get_high_value : Int32
      @high
    end

    def set_display_type(view_type : CRT::HistViewType)
      @view_type = view_type
    end

    def get_view_type : CRT::HistViewType
      @view_type
    end

    def set_stats_pos(stats_pos : Int32)
      @stats_pos = stats_pos
    end

    def get_stats_pos : Int32
      @stats_pos
    end

    def set_stats_attr(stats_attr : Int32)
      @stats_attr = stats_attr
    end

    def get_stats_attr : Int32
      @stats_attr
    end

    def set_filler_char(character : Int32)
      @filler = character
    end

    def get_filler_char : Int32
      @filler
    end

    def draw(box : Bool)
      return unless w = @win

      fattr = @filler & ~0xFF
      hist_x = @title_lines + 1
      hist_y = @bar_size

      w.erase

      Draw.draw_obj_box(w, self) if box
      Draw.draw_shadow(@shadow_win)
      draw_title(w)

      # Draw stat labels
      if @view_type != CRT::HistViewType::NONE
        if @low_string.size > 0
          Draw.write_char_attrib(w, @lowx, @lowy, @low_string,
            @stats_attr, @orient == CRT::VERTICAL ? CRT::VERTICAL : CRT::HORIZONTAL,
            0, @low_string.size)
        end

        if @cur_string.size > 0
          Draw.write_char_attrib(w, @curx, @cury, @cur_string,
            @stats_attr, @orient == CRT::VERTICAL ? CRT::VERTICAL : CRT::HORIZONTAL,
            0, @cur_string.size)
        end

        if @high_string.size > 0
          Draw.write_char_attrib(w, @highx, @highy, @high_string,
            @stats_attr, @orient == CRT::VERTICAL ? CRT::VERTICAL : CRT::HORIZONTAL,
            0, @high_string.size)
        end
      end

      if @orient == CRT::VERTICAL
        hist_x = @box_height - @bar_size - 1
        hist_y = @field_width
      end

      # Draw the histogram bar
      (hist_x...@box_height - 1).each do |x|
        (1..hist_y).each do |y|
          battr = LibNCurses.mvwinch(w, x, y).to_i32
          if (battr & 0xFF) == ' '.ord
            Draw.mvwaddch(w, x, y, @filler)
          else
            Draw.mvwaddch(w, x, y, battr | fattr)
          end
        end
      end

      wrefresh
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clean_bindings(:HISTOGRAM)
      CRT::Screen.unregister(:HISTOGRAM, self)
    end

    def set_bk_attr(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
    end

    def focus
      draw(@box)
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :HISTOGRAM
    end

    private def format_value_string : String
      case @view_type
      when CRT::HistViewType::PERCENT
        "%3.1f%%" % [100.0 * @percent]
      when CRT::HistViewType::FRACTION
        "%d/%d" % [@value, @high]
      else
        @value.to_s
      end
    end

    private def set_vertical_labels
      if @stats_pos == CRT::LEFT || @stats_pos == CRT::BOTTOM
        @low_string = @low.to_s
        @lowx = 1
        @lowy = @box_height - @low_string.size - 1

        @high_string = @high.to_s
        @highx = 1
        @highy = @title_lines + 1

        @cur_string = format_value_string
        @curx = 1
        @cury = (@field_height - @cur_string.size) // 2 + @title_lines + 1
      elsif @stats_pos == CRT::CENTER
        @low_string = @low.to_s
        @lowx = @field_width // 2 + 1
        @lowy = @box_height - @low_string.size - 1

        @high_string = @high.to_s
        @highx = @field_width // 2 + 1
        @highy = @title_lines + 1

        @cur_string = format_value_string
        @curx = @field_width // 2 + 1
        @cury = (@field_height - @cur_string.size) // 2 + @title_lines + 1
      elsif @stats_pos == CRT::RIGHT || @stats_pos == CRT::TOP
        @low_string = @low.to_s
        @lowx = @field_width
        @lowy = @box_height - @low_string.size - 1

        @high_string = @high.to_s
        @highx = @field_width
        @highy = @title_lines + 1

        @cur_string = format_value_string
        @curx = @field_width
        @cury = (@field_height - @cur_string.size) // 2 + @title_lines + 1
      end
    end

    private def set_horizontal_labels
      if @stats_pos == CRT::TOP || @stats_pos == CRT::RIGHT
        @low_string = @low.to_s
        @lowx = 1
        @lowy = @title_lines + 1

        @high_string = @high.to_s
        @highx = @box_width - @high_string.size - 1
        @highy = @title_lines + 1

        @cur_string = format_value_string
        @curx = (@field_width - @cur_string.size) // 2 + 1
        @cury = @title_lines + 1
      elsif @stats_pos == CRT::CENTER
        @low_string = @low.to_s
        @lowx = 1
        @lowy = @field_height // 2 + @title_lines + 1

        @high_string = @high.to_s
        @highx = @box_width - @high_string.size - 1
        @highy = @field_height // 2 + @title_lines + 1

        @cur_string = format_value_string
        @curx = (@field_width - @cur_string.size) // 2 + 1
        @cury = @field_height // 2 + @title_lines + 1
      elsif @stats_pos == CRT::BOTTOM || @stats_pos == CRT::LEFT
        @low_string = @low.to_s
        @lowx = 1
        @lowy = @box_height - 2 * @border_size

        @high_string = @high.to_s
        @highx = @box_width - @high_string.size - 1
        @highy = @box_height - 2 * @border_size

        @cur_string = format_value_string
        @curx = (@field_width - @cur_string.size) // 2 + 1
        @cury = @box_height - 2 * @border_size
      end
    end
  end
end
