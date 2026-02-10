module CRT
  class Graph < CRT::CRTObjs
    property values : Array(Int32) = [] of Int32
    property count : Int32 = 0
    property display_type : Symbol = :LINE
    property parent : NCurses::Window? = nil

    @xtitle : Array(Int32) = [] of Int32
    @xtitle_len : Int32 = 0
    @xtitle_pos : Int32 = 0
    @ytitle : Array(Int32) = [] of Int32
    @ytitle_len : Int32 = 0
    @ytitle_pos : Int32 = 0
    @graph_char : Array(Int32) = [] of Int32
    @minx : Int32 = 0
    @maxx : Int32 = 0
    @xscale : Int32 = 1
    @yscale : Int32 = 1

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, title : String = "",
                   xtitle : String = "", ytitle : String = "")
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(false)

      box_height = CRT.set_widget_dimension(parent_height, height, 3)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)
      box_width = set_title(title, box_width)
      box_height += @title_lines
      box_width = {parent_width, box_width}.min
      box_height = {parent_height, box_height}.min

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

      @box_height = box_height
      @box_width = box_width

      # X axis title
      if !xtitle.empty?
        xtitle_len_arr = [] of Int32
        xtitle_pos_arr = [] of Int32
        @xtitle = char2chtype(xtitle, xtitle_len_arr, xtitle_pos_arr)
        @xtitle_len = xtitle_len_arr[0]
        @xtitle_pos = justify_string(@box_height, @xtitle_len, xtitle_pos_arr[0])
      end

      # Y axis title
      if !ytitle.empty?
        ytitle_len_arr = [] of Int32
        ytitle_pos_arr = [] of Int32
        @ytitle = char2chtype(ytitle, ytitle_len_arr, ytitle_pos_arr)
        @ytitle_len = ytitle_len_arr[0]
        @ytitle_pos = justify_string(@box_width, @ytitle_len, ytitle_pos_arr[0])
      end

      @graph_char = [] of Int32
      @values = [] of Int32

      cdkscreen.register(:GRAPH, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)
      0
    end

    def set_values(values : Array(Int32), start_at_zero : Bool) : Bool
      return false if values.size < 0

      @values = [] of Int32
      @count = 0
      min = Int32::MAX
      max = Int32::MIN

      values.each do |value|
        min = {value, min}.min
        max = {value, max}.max
        @values << value
      end

      @count = values.size
      @minx = min
      @maxx = max
      @minx = 0 if start_at_zero

      set_scales
      true
    end

    def characters=(characters : String) : Bool
      char_count = [] of Int32
      new_tokens = char2chtype(characters, char_count, [] of Int32)
      return false if char_count[0] != @count
      @graph_char = new_tokens
      true
    end

    def display_type=(type : Symbol)
      @display_type = type
    end

    def display_type : Symbol
      @display_type
    end

    def draw(box : Bool)
      return unless w = @win

      adj = 2 + (@xtitle.size > 0 ? 1 : 0)

      Draw.draw_obj_box(w, self) if box

      # Draw vertical axis
      Draw.draw_line(w, 2, @title_lines + 1, 2, @box_height - 3,
        Draw::ACS_VLINE)
      # Draw horizontal axis
      Draw.draw_line(w, 3, @box_height - 3, @box_width, @box_height - 3,
        Draw::ACS_HLINE)

      draw_title(w)

      # X axis title
      if @xtitle.size > 0
        Draw.write_chtype(w, 0, @xtitle_pos, @xtitle, CRT::VERTICAL,
          0, @xtitle_len)
      end

      # X axis labels
      attrib = ' '.ord | LibNCurses::Attribute::Reverse.value.to_i32
      temp = @maxx.to_s
      Draw.write_char_attrib(w, 1, @title_lines + 1, temp, attrib,
        CRT::VERTICAL, 0, temp.size)
      temp = @minx.to_s
      Draw.write_char_attrib(w, 1, @box_height - 2 - temp.size, temp, attrib,
        CRT::VERTICAL, 0, temp.size)

      # Y axis title
      if @ytitle.size > 0
        Draw.write_chtype(w, @ytitle_pos, @box_height - 1, @ytitle,
          CRT::HORIZONTAL, 0, @ytitle_len)
      end

      # Y axis labels
      temp = @count.to_s
      Draw.write_char_attrib(w, @box_width - temp.size - adj, @box_height - 2,
        temp, attrib, CRT::HORIZONTAL, 0, temp.size)
      Draw.write_char_attrib(w, 3, @box_height - 2, "0", attrib,
        CRT::HORIZONTAL, 0, 1)

      if @count == 0
        wrefresh
        return
      end

      spacing = (@box_width - 3) // @count

      # Draw graph data
      @count.times do |y|
        colheight = @xscale > 0 ? (@values[y] // @xscale) - 1 : 0
        graph_ch = y < @graph_char.size ? @graph_char[y] : '#'.ord

        # Tick mark on Y axis
        Draw.mvwaddch(w, @box_height - 3, (y + 1) * spacing + adj,
          Draw::ACS_HLINE | LibNCurses::Attribute::Bold.value.to_i32)

        if @display_type == :PLOT
          xp = @box_height - 4 - colheight
          yp = (y + 1) * spacing + adj
          Draw.mvwaddch(w, xp, yp, graph_ch) if xp >= 0
        else
          xp = @box_height - 3
          yp = (y + 1) * spacing + adj
          if colheight > 0
            Draw.draw_line(w, yp, xp - colheight, yp, xp, graph_ch)
          end
        end
      end

      # Axis corners
      Draw.mvwaddch(w, @title_lines, 2, Draw::ACS_URCORNER)
      Draw.mvwaddch(w, @box_height - 3, 2, Draw::ACS_LLCORNER)

      wrefresh
    end

    def erase
      CRT.erase_curses_window(@win)
    end

    def destroy
      clean_title
      clean_bindings(:GRAPH)
      CRT::Screen.unregister(:GRAPH, self)
      CRT.delete_curses_window(@win)
    end

    def background=(attrib : Int32)
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
      :GRAPH
    end

    private def set_scales
      @xscale = (@maxx - @minx) // {1, @box_height - @title_lines - 5}.max
      @xscale = 1 if @xscale <= 0
      @yscale = (@box_width - 4) // {1, @count}.max
      @yscale = 1 if @yscale <= 0
    end
  end
end
