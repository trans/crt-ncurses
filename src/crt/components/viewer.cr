module CRT
  class Viewer < CRT::CRTObjs
    DOWN = 0
    UP   = 1

    @button : Array(Array(Int32)) = [] of Array(Int32)
    @button_len : Array(Int32) = [] of Int32
    @button_pos : Array(Int32) = [] of Int32
    @button_count : Int32 = 0
    @button_highlight : Int32 = 0
    @current_button : Int32 = 0

    @list : Array(Array(Int32)) = [] of Array(Int32)
    @list_pos : Array(Int32) = [] of Int32
    @list_len : Array(Int32) = [] of Int32
    @list_size : Int32 = 0
    @widest_line : Int32 = 0

    @view_size : Int32 = 0
    @current_top : Int32 = 0
    @max_top_line : Int32 = 0
    @left_char : Int32 = 0
    @max_left_char : Int32 = 0
    @characters : Int32 = 0
    @show_line_info : Bool = true
    @in_progress : Bool = false
    @interpret : Bool = true
    @title_adj : Int32 = 0
    @shadow : Bool = false
    @parent : NCurses::Window? = nil
    @complete : Bool = false

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32,
                   buttons : Array(String) = ["OK"],
                   button_highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      button_width = 0

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)

      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @button_count = buttons.size
      if buttons.size > 0
        (0...buttons.size).each do |x|
          button_len_arr = [] of Int32
          @button << char2chtype(buttons[x], button_len_arr, [] of Int32)
          @button_len << button_len_arr[0]
          button_width += @button_len[x] + 1
        end
        button_adj = (box_width - button_width) // (buttons.size + 1)
        button_pos = 1 + button_adj
        (0...buttons.size).each do |x|
          @button_pos << button_pos
          button_pos += button_adj + @button_len[x]
        end
      end

      @screen = cdkscreen
      @parent = parent_window
      @button_highlight = button_highlight
      @box_height = box_height
      @box_width = box_width - 2
      @view_size = box_height - 2
      @input_window = @win
      @shadow = shadow
      @current_button = 0
      @current_top = 0
      @left_char = 0
      @max_left_char = 0
      @max_top_line = 0
      @characters = 0
      @list_size = 0
      @show_line_info = true
      @accepts_focus = true
      @exit_type = CRT::ExitType::EARLY_EXIT

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width + 1,
          y: ypos + 1, x: xpos + 1)
      end

      bind(:VIEWER, CRT::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)
      bind(:VIEWER, 'b'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(:VIEWER, 'B'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(:VIEWER, CRT::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(:VIEWER, ' '.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(:VIEWER, 'f'.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(:VIEWER, 'F'.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(:VIEWER, '|'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:VIEWER, '$'.ord, :getc, LibNCurses::Key::End.value)

      cdkscreen.register(:VIEWER, self)
    end

    def set_viewer_title(title : String)
      set_title(title, -(@box_width + 1))
      @title_adj = @title_lines
      @view_size = @box_height - (@title_lines + 1) - 2
    end

    def set_info(list : Array(String), list_size : Int32, interpret : Bool) : Int32
      viewer_size = list_size < 0 ? list.size : list_size
      @in_progress = true
      @list = [] of Array(Int32)
      @list_pos = [] of Int32
      @list_len = [] of Int32
      @widest_line = 0
      @interpret = interpret

      current_line = 0
      x = 0
      while x < list_size && current_line < viewer_size
        if list[x].empty?
          @list << [] of Int32
          @list_len << 0
          @list_pos << 0
          current_line += 1
        else
          setup_line(interpret, list[x], current_line)
          @characters += @list_len[current_line]
          current_line += 1
        end
        x += 1
      end

      if @widest_line > @box_width
        @max_left_char = (@widest_line - @box_width) + 1
      else
        @max_left_char = 0
      end

      @in_progress = false
      @list_size = current_line
      if @list_size <= @view_size
        @max_top_line = 0
      else
        @max_top_line = @list_size - 1
      end
      @list_size
    end

    def set_highlight(button_highlight : Int32)
      @button_highlight = button_highlight
    end

    def set_info_line(show : Bool)
      @show_line_info = show
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      @current_button = 0
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          input = getch([] of Bool)
          ret = inject(input)
          return ret if @exit_type != CRT::ExitType::EARLY_EXIT
        end
      else
        actions.each do |action|
          ret = inject(action)
          return ret if @exit_type != CRT::ExitType::EARLY_EXIT
        end
      end
      -1
    end

    def inject(input : Int32) : Int32
      refresh = false
      @complete = false

      set_exit_type(0)

      if check_bind(:VIEWER, input)
        @complete = true
      else
        case input
        when CRT::KEY_TAB
          if @button_count > 1
            @current_button = (@current_button + 1) % @button_count
            draw_buttons
          end
        when CRT::PREV
          if @button_count > 1
            @current_button = (@current_button - 1) % @button_count
            @current_button = @button_count - 1 if @current_button < 0
            draw_buttons
          end
        when LibNCurses::Key::Up.value
          if @current_top > 0
            @current_top -= 1
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::Down.value
          if @current_top < @max_top_line
            @current_top += 1
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::Right.value
          if @left_char < @max_left_char
            @left_char += 1
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::Left.value
          if @left_char > 0
            @left_char -= 1
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::PageUp.value
          if @current_top > 0
            if @current_top - (@view_size - 1) > 0
              @current_top = @current_top - (@view_size - 1)
            else
              @current_top = 0
            end
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::PageDown.value
          if @current_top < @max_top_line
            if @current_top + @view_size < @max_top_line
              @current_top = @current_top + (@view_size - 1)
            else
              @current_top = @max_top_line
            end
            refresh = true
          else
            CRT.beep
          end
        when LibNCurses::Key::Home.value
          @left_char = 0
          refresh = true
        when LibNCurses::Key::End.value
          @left_char = @max_left_char
          refresh = true
        when 'g'.ord, '1'.ord, '<'.ord
          @current_top = 0
          refresh = true
        when 'G'.ord, '>'.ord
          @current_top = @max_top_line
          refresh = true
        when CRT::KEY_ESC
          set_exit_type(input)
          @complete = true
          return -1
        when CRT::KEY_RETURN, LibNCurses::Key::Enter.value
          set_exit_type(input)
          @complete = true
          return @current_button
        when CRT::REFRESH
          if scr = @screen
            scr.erase
            scr.refresh
          end
        else
          CRT.beep
        end
      end

      draw_info if refresh
      @complete ? 0 : -1
    end

    def draw(box : Bool)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        wrefresh
      end

      draw_info
    end

    def draw_buttons
      return if @button_count == 0
      return unless w = @win

      (0...@button_count).each do |x|
        Draw.write_chtype(w, @button_pos[x], @box_height - 2,
          @button[x], CRT::HORIZONTAL, 0, @button_len[x])
      end

      # Highlight the current button
      (0...@button_len[@current_button]).each do |x|
        ch = @button[@current_button][x]
        char_byte = ch & 0xFF
        Draw.mvwaddch(w, @box_height - 2, @button_pos[@current_button] + x,
          char_byte | @button_highlight)
      end

      wrefresh
    end

    def draw_info
      return unless w = @win
      list_adjust = false

      w.erase
      draw_title(w)

      if @show_line_info
        temp = if @in_progress
                 "processing..."
               elsif @list_size != 0
                 pct = ((1.0 * @current_top + 1) / @list_size) * 100
                 "#{@current_top + 1}/#{@list_size} #{pct.to_i}%%"
               else
                 "0/0 0%%"
               end

        if @title_lines == 0 || (!@title_pos.empty? && @title_pos[0] < temp.size + 2)
          list_adjust = true
        end
        Draw.write_char(w, 1,
          (list_adjust ? @title_lines : 0) + 1,
          temp, CRT::HORIZONTAL, 0, temp.size)
      end

      last_line = {@list_size, @view_size}.min
      last_line -= (list_adjust ? 1 : 0)

      (0...last_line).each do |x|
        if @current_top + x < @list_size
          screen_pos = @list_pos[@current_top + x] + 1 - @left_char

          Draw.write_chtype(w,
            screen_pos >= 0 ? screen_pos : 1,
            x + @title_lines + (list_adjust ? 1 : 0) + 1,
            @list[x + @current_top], CRT::HORIZONTAL,
            screen_pos >= 0 ? 0 : @left_char - @list_pos[@current_top + x],
            @list_len[x + @current_top])
        end
      end

      if @box
        Draw.draw_obj_box(w, self)
        wrefresh
      end

      if @button_count > 0
        boxattr = @bx_attr

        (1..@box_width).each do |x|
          Draw.mvwaddch(w, @box_height - 3, x, @hz_char | boxattr)
        end

        Draw.mvwaddch(w, @box_height - 3, 0,
          Draw::ACS_VLINE | boxattr)
        Draw.mvwaddch(w, @box_height - 3, w.max_x - 1,
          Draw::ACS_VLINE | boxattr)
      end

      draw_buttons
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      @list = [] of Array(Int32)
      @list_pos = [] of Int32
      @list_len = [] of Int32
      clean_title
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clean_bindings(:VIEWER)
      CRT::Screen.unregister(:VIEWER, self)
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
      :VIEWER
    end

    private def setup_line(interpret : Bool, list : String, x : Int32)
      if interpret
        list_len_arr = [] of Int32
        list_pos_arr = [] of Int32
        chtype_arr = char2chtype(list, list_len_arr, list_pos_arr)
        if x < @list.size
          @list[x] = chtype_arr
          @list_len[x] = list_len_arr[0]
          @list_pos[x] = justify_string(@box_width, @list_len[x], list_pos_arr[0])
        else
          @list << chtype_arr
          @list_len << list_len_arr[0]
          @list_pos << justify_string(@box_width, list_len_arr[0], list_pos_arr[0])
        end
      else
        t = String.build do |s|
          i = 0
          while i < list.size
            ch = list[i]
            if ch == '\t'
              loop do
                s << ' '
                i += 1
                break unless (i & 7) != 0
              end
            elsif ch.printable?
              s << ch
              i += 1
            else
              s << '?'
              i += 1
            end
          end
        end
        plain = t.chars.map { |c| c.ord }
        if x < @list.size
          @list[x] = plain
          @list_len[x] = plain.size
          @list_pos[x] = 0
        else
          @list << plain
          @list_len << plain.size
          @list_pos << 0
        end
      end
      @widest_line = {@widest_line, @list_len[x]}.max
    end
  end
end
