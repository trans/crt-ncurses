module CRT
  class ScrollWindow < CRT::CRTObjs
    @field_win : NCurses::Window? = nil
    @list : Array(Array(Int32)) = [] of Array(Int32)
    @list_pos : Array(Int32) = [] of Int32
    @list_len : Array(Int32) = [] of Int32
    @view_size : Int32 = 0
    @current_top : Int32 = 0
    @max_top_line : Int32 = 0
    @left_char : Int32 = 0
    @max_left_char : Int32 = 0
    @list_size : Int32 = 0
    @widest_line : Int32 = -1
    @save_lines : Int32 = 0
    @shadow : Bool = false
    @parent : NCurses::Window? = nil
    @title_adj : Int32 = 0
    @complete : Bool = false

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, save_lines : Int32,
                   title : String = "", box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)
      box_width = set_title(title, box_width)

      box_height += @title_lines + 1
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      @title_adj = @title_lines + 1

      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @field_win = CRT.subwin(w, box_height - @title_lines - 2, box_width - 2,
        ypos + @title_lines + 1, xpos + 1)
      if fw = @field_win
        fw.keypad(true)
      end

      @screen = cdkscreen
      @parent = parent_window
      @box_height = box_height
      @box_width = box_width
      @view_size = box_height - @title_lines - 2
      @current_top = 0
      @max_top_line = 0
      @left_char = 0
      @max_left_char = 0
      @list_size = 0
      @widest_line = -1
      @save_lines = save_lines
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      create_list(save_lines)

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      bind(object_type, CRT::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)
      bind(object_type, 'b'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(object_type, 'B'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(object_type, CRT::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(object_type, ' '.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(object_type, 'f'.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(object_type, 'F'.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(object_type, '|'.ord, :getc, LibNCurses::Key::Home.value)
      bind(object_type, '$'.ord, :getc, LibNCurses::Key::End.value)

      cdkscreen.register(object_type, self)
    end

    def setup_line(list : String, x : Int32)
      list_len_arr = [] of Int32
      list_pos_arr = [] of Int32
      @list[x] = char2chtype(list, list_len_arr, list_pos_arr)
      @list_len[x] = list_len_arr[0]
      @list_pos[x] = justify_string(@box_width, list_len_arr[0], list_pos_arr[0])
      @widest_line = {@widest_line, @list_len[x]}.max
    end

    def contents=(list : Array(String))
      clean
      create_list(list.size)

      (0...list.size).each do |x|
        setup_line(list[x], x)
      end

      @list_size = list.size
      @max_top_line = {@list_size - @view_size, 0}.max
      @max_left_char = @widest_line - (@box_width - 2)
      @current_top = 0
      @left_char = 0
    end

    def add(list : String, insert_pos : Int32)
      if @list_size == @save_lines && @list_size > 0
        @list = @list[1..]
        @list_pos = @list_pos[1..]
        @list_len = @list_len[1..]
        @list_size -= 1
      end

      if insert_pos == CRT::TOP
        @list = [[] of Int32] + @list
        @list_pos = [0] + @list_pos
        @list_len = [0] + @list_len
        setup_line(list, 0)

        @current_top = 0
        @list_size += 1 if @list_size < @save_lines
        @max_top_line = {@list_size - @view_size, 0}.max
        @max_left_char = @widest_line - (@box_width - 2)
      else
        @list << [] of Int32
        @list_pos << 0
        @list_len << 0
        setup_line(list, @list_size)

        @max_left_char = @widest_line - (@box_width - 2)
        @list_size += 1 if @list_size < @save_lines

        if @list_size <= @view_size
          @max_top_line = 0
          @current_top = 0
        else
          @max_top_line = @list_size - @view_size
          @current_top = @max_top_line
        end
      end

      draw_list(@box)
    end

    def jump_to_line(line : Int32)
      if line == CRT::BOTTOM || line >= @list_size
        @current_top = @list_size - @view_size
      elsif line == CRT::TOP || line <= 0
        @current_top = 0
      else
        if @view_size + line < @list_size
          @current_top = line
        else
          @current_top = @list_size - @view_size
        end
      end

      @current_top = 0 if @current_top < 0
      draw(@box)
    end

    def clean
      @list = [] of Array(Int32)
      @list_pos = [] of Int32
      @list_len = [] of Int32
      @list_size = 0
      @max_left_char = 0
      @widest_line = 0
      @current_top = 0
      @max_top_line = 0
    end

    def trim(begin_line : Int32, end_line : Int32)
      start = begin_line.clamp(0, {@list_size - 1, 0}.max)
      finish = end_line.clamp(0, {@list_size - 1, 0}.max)
      return if start > finish

      @list.delete_at(start..finish)
      @list_pos.delete_at(start..finish)
      @list_len.delete_at(start..finish)

      @list_size = @list.size
      @max_top_line = {@list_size - @view_size, 0}.max
      @current_top = {@current_top, @max_top_line}.min

      draw(@box)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
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

      set_exit_type(0)
      -1
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw(@box)

      if check_bind(object_type, input)
        @complete = true
      else
        case input
        when LibNCurses::Key::Up.value
          if @current_top > 0
            @current_top -= 1
          else
            CRT.beep
          end
        when LibNCurses::Key::Down.value
          if @current_top >= 0 && @current_top < @max_top_line
            @current_top += 1
          else
            CRT.beep
          end
        when LibNCurses::Key::Right.value
          if @left_char < @max_left_char
            @left_char += 1
          else
            CRT.beep
          end
        when LibNCurses::Key::Left.value
          if @left_char > 0
            @left_char -= 1
          else
            CRT.beep
          end
        when LibNCurses::Key::PageUp.value
          if @current_top != 0
            if @current_top >= @view_size
              @current_top = @current_top - (@view_size - 1)
            else
              @current_top = 0
            end
          else
            CRT.beep
          end
        when LibNCurses::Key::PageDown.value
          if @current_top != @max_top_line
            if @current_top + @view_size < @max_top_line
              @current_top = @current_top + (@view_size - 1)
            else
              @current_top = @max_top_line
            end
          else
            CRT.beep
          end
        when LibNCurses::Key::Home.value
          @left_char = 0
        when LibNCurses::Key::End.value
          @left_char = @max_left_char + 1
        when 'g'.ord, '1'.ord, '<'.ord
          @current_top = 0
        when 'G'.ord, '>'.ord
          @current_top = @max_top_line
        when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
          set_exit_type(input)
          ret = 1
          @complete = true
        when CRT::KEY_ESC
          set_exit_type(input)
          @complete = true
        when CRT::REFRESH
          if scr = @screen
            scr.erase
            scr.refresh
          end
        end
      end

      unless @complete
        draw_list(@box)
        set_exit_type(0)
      end

      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)
        wrefresh
      end

      draw_list(box)
    end

    def draw_list(box : Bool)
      return unless fw = @field_win

      last_line = {@list_size, @view_size}.min
      fw.erase

      (0...last_line).each do |x|
        idx = x + @current_top
        next if idx >= @list_size

        screen_pos = @list_pos[idx] - @left_char

        if screen_pos >= 0
          Draw.write_chtype(fw, screen_pos, x,
            @list[idx], CRT::HORIZONTAL, 0,
            @list_len[idx])
        else
          Draw.write_chtype(fw, 0, x, @list[idx],
            CRT::HORIZONTAL, @left_char - @list_pos[idx],
            @list_len[idx])
        end
      end

      CRT::Screen.wrefresh(fw)
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
      CRT.delete_curses_window(@field_win)
      CRT.delete_curses_window(@win)
      clean_bindings(object_type)
      CRT::Screen.unregister(object_type, self)
    end

    def background=(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
      if fw = @field_win
        LibNCurses.wbkgd(fw, attrib.to_u32)
      end
    end

    def focus
      draw(@box)
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :SCROLL_WINDOW
    end

    private def create_list(list_size : Int32)
      @list = [] of Array(Int32)
      @list_pos = [] of Int32
      @list_len = [] of Int32
    end
  end
end
