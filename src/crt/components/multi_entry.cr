module CRT
  class MultiEntry < CRT::CRTObjs
    property info : String = ""
    getter current_col : Int32 = 0
    getter current_row : Int32 = 0
    getter top_row : Int32 = 0
    property disp_type : CRT::DisplayType = CRT::DisplayType::MIXED
    getter field_width : Int32 = 0
    getter rows : Int32 = 0

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @field_attr : Int32 = 0
    @filler : Int32 = '.'.ord
    @hidden : Int32 = '.'.ord
    @total_width : Int32 = 0
    @logical_rows : Int32 = 0
    @min : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : String = ""
    @parent : NCurses::Window? = nil

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   field_width : Int32, field_rows : Int32, logical_rows : Int32,
                   title : String = "", label : String = "", field_attr : Int32 = 0,
                   filler : Char = ' ', disp_type : CRT::DisplayType = CRT::DisplayType::MIXED,
                   min : Int32 = 0, box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)

      field_width = CRT.set_widget_dimension(parent_width, field_width, 0)
      field_rows = CRT.set_widget_dimension(parent_height, field_rows, 0)
      box_height = field_rows + 2 * @border_size

      # Translate label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        @label, @label_len, _ = char2chtype(label)
      end

      box_width = @label_len + field_width + 2 * @border_size

      old_width = box_width
      box_width = set_title(title, box_width)
      horizontal_adjust = (box_width - old_width) // 2

      box_height += @title_lines

      # Clamp
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min
      field_width = {box_width - @label_len - 2 * @border_size, field_width}.min
      field_rows = {box_height - @title_lines - 2 * @border_size, field_rows}.min

      # Align
      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Label window
      if @label.size > 0
        @label_win = CRT.subwin(w, field_rows, @label_len + 2 * @border_size,
          ypos + @title_lines + @border_size, xpos + horizontal_adjust + @border_size)
      end

      # Field window
      @field_win = CRT.subwin(w, field_rows, field_width,
        ypos + @title_lines + @border_size, xpos + @label_len + horizontal_adjust + @border_size)
      if fw = @field_win
        fw.keypad(true)
      end

      @parent = parent_window
      @total_width = field_width * logical_rows + 1
      @info = ""

      @screen = screen
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @rows = field_rows
      @box_height = box_height
      @box_width = box_width
      @filler = filler.ord
      @hidden = filler.ord
      @input_window = @win
      @accepts_focus = true
      @current_row = 0
      @current_col = 0
      @top_row = 0
      @shadow = shadow
      @disp_type = disp_type
      @min = min
      @logical_rows = logical_rows

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : String
      draw(@box)

      begin
        if actions.nil? || actions.empty?
          loop do
            LibNCurses.curs_set(2)
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
        ""
      ensure
        LibNCurses.curs_set(0)
      end
    end

    def cursor_pos : Int32
      (@current_row + @top_row) * @field_width + @current_col
    end

    def set_top_row(row : Int32) : Bool
      if @top_row != row
        @top_row = row
        true
      else
        false
      end
    end

    def set_cur_pos(row : Int32, col : Int32) : Bool
      if @current_row != row || @current_col != col
        @current_row = row
        @current_col = col
        true
      else
        false
      end
    end

    def handle_key_left(moved : Bool, redraw : Bool) : {Bool, Bool, Bool}
      if @current_col != 0
        moved = set_cur_pos(@current_row, @current_col - 1)
      elsif @current_row == 0
        if @top_row != 0
          moved = set_cur_pos(@current_row, @field_width - 1)
          redraw = set_top_row(@top_row - 1)
        end
      else
        moved = set_cur_pos(@current_row - 1, @field_width - 1)
      end

      if !moved && !redraw
        CRT.beep
        return {false, moved, redraw}
      end
      {true, moved, redraw}
    end

    def inject(input : Int32) : String
      cur_pos = self.cursor_pos
      @complete = false

      set_exit_type(0)
      draw_field

      moved = false
      redraw = false

      case input
      when LibNCurses::Key::Home.value
        moved = set_cur_pos(0, 0)
        redraw = set_top_row(0)
      when LibNCurses::Key::End.value
        field_characters = @rows * @field_width
        if @info.size < field_characters
          redraw = set_top_row(0)
          moved = set_cur_pos(@info.size // @field_width, @info.size % @field_width)
        else
          redraw = set_top_row(@info.size // @field_width - @rows + 1)
          moved = set_cur_pos(@rows - 1, @info.size % @field_width)
        end
      when LibNCurses::Key::Left.value
        _, moved, redraw = handle_key_left(moved, redraw)
      when LibNCurses::Key::Right.value
        if @current_col < @field_width - 1
          if cur_pos + 1 <= @info.size
            moved = set_cur_pos(@current_row, @current_col + 1)
          end
        elsif @current_row == @rows - 1
          if @top_row + @current_row + 1 < @logical_rows
            moved = set_cur_pos(@current_row, 0)
            redraw = set_top_row(@top_row + 1)
          end
        else
          moved = set_cur_pos(@current_row + 1, 0)
        end
        CRT.beep if !moved && !redraw
      when LibNCurses::Key::Down.value
        if @current_row != @rows - 1
          if cur_pos + @field_width + 1 <= @info.size
            moved = set_cur_pos(@current_row + 1, @current_col)
          end
        elsif @top_row < @logical_rows - @rows
          if (@top_row + @current_row + 1) * @field_width <= @info.size
            redraw = set_top_row(@top_row + 1)
          end
        end
        CRT.beep if !moved && !redraw
      when LibNCurses::Key::Up.value
        if @current_row != 0
          moved = set_cur_pos(@current_row - 1, @current_col)
        elsif @top_row != 0
          redraw = set_top_row(@top_row - 1)
        end
        CRT.beep if !moved && !redraw
      when LibNCurses::Key::Backspace.value, CRT::DELETE
        if @disp_type == CRT::DisplayType::VIEWONLY
          CRT.beep
        elsif @info.size == 0
          CRT.beep
        elsif input == CRT::DELETE
          # Delete char at cursor
          cp = cursor_pos
          if cp < @info.size
            @info = @info[0...cp] + @info[cp + 1..]
            draw_field
          else
            CRT.beep
          end
        else
          # Backspace - move left then delete
          hkl, moved, redraw = handle_key_left(moved, redraw)
          if hkl
            cp = cursor_pos
            if cp < @info.size
              @info = @info[0...cp] + @info[cp + 1..]
              draw_field
            else
              CRT.beep
            end
          end
        end
      when CRT::TRANSPOSE
        cp = cursor_pos
        if cp >= @info.size - 1
          CRT.beep
        else
          chars = @info.chars
          chars[cp], chars[cp + 1] = chars[cp + 1], chars[cp]
          @info = chars.join
          draw_field
        end
      when CRT::ERASE
        if @info.size != 0
          clean
          draw_field
        end
      when CRT::CUT
        if @info.size == 0
          CRT.beep
        else
          CRT::CRTObjs.paste_buffer = @info.clone
          clean
          draw_field
        end
      when CRT::COPY
        if @info.size == 0
          CRT.beep
        else
          CRT::CRTObjs.paste_buffer = @info.clone
        end
      when CRT::PASTE
        if CRT::CRTObjs.paste_buffer.size == 0
          CRT.beep
        else
          self.value = CRT::CRTObjs.paste_buffer
          draw(@box)
        end
      when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        if @info.size < @min + 1
          CRT.beep
        else
          set_exit_type(input)
          @complete = true
          return @info
        end
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        if @disp_type == CRT::DisplayType::VIEWONLY || @info.size >= @total_width
          CRT.beep
        else
          # Filter character and insert
          newchar = Display.filter_by_display_type(@disp_type, input)
          if newchar == -1
            CRT.beep
          else
            cp = cursor_pos
            @info = @info[0...cp] + newchar.chr.to_s + @info[cp..]
            @current_col += 1

            # Wrap to next row if past field width
            if @current_col >= @field_width
              @current_col = 0
              @current_row += 1

              if @current_row == @rows
                @current_row -= 1
                @top_row += 1
              end
            end

            draw_field
          end
        end
      end

      if redraw
        draw_field
      elsif moved
        if fw = @field_win
          fw.move(@current_row, @current_col)
          CRT::Screen.wrefresh(fw)
        end
      end

      unless @complete
        set_exit_type(0)
      end

      @result_data = @info
      @info
    end

    def draw_field
      return unless fw = @field_win

      currchar = @field_width * @top_row

      if w = @win
        draw_title(w)
        wrefresh
      end

      lastpos = @info.size

      @rows.times do |x|
        @field_width.times do |y|
          if currchar < lastpos
            if Display.hidden_display_type?(@disp_type)
              Draw.mvwaddch(fw, x, y, @filler)
            else
              Draw.mvwaddch(fw, x, y, @info[currchar].ord | @field_attr)
              currchar += 1
            end
          else
            Draw.mvwaddch(fw, x, y, @filler)
          end
        end
      end

      fw.move(@current_row, @current_col)
      CRT::Screen.wrefresh(fw)
    end

    def draw(box : Bool = @box)
      if w = @win
        Draw.draw_obj_box(w, self) if box
        wrefresh
      end

      Draw.draw_shadow(@shadow_win)

      if lw = @label_win
        Draw.write_chtype(lw, 0, 0, @label, CRT::HORIZONTAL, 0, @label_len)
        CRT::Screen.wrefresh(lw)
      end

      draw_field
    end

    def erase
      CRT.erase_curses_window(@field_win)
      CRT.erase_curses_window(@label_win)
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
      clean_title
      CRT.delete_curses_window(@field_win)
      CRT.delete_curses_window(@label_win)
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clear_key_bindings
      CRT::Screen.unregister(object_type, self)
    end

    def value=(new_value : String)
      field_characters = @rows * @field_width
      @info = new_value

      if new_value.size < field_characters
        @top_row = 0
        @current_row = new_value.size // @field_width
        @current_col = new_value.size % @field_width
      else
        row_used = new_value.size // @field_width
        @top_row = row_used - @rows + 1
        @current_row = @rows - 1
        @current_col = new_value.size % @field_width
      end

      draw_field
    end

    def value : String
      @info
    end

    def filler_char=(filler : Char)
      @filler = filler.ord
    end

    def filler_char : Int32
      @filler
    end

    def hidden_char=(character : Char)
      @hidden = character.ord
    end

    def hidden_char : Int32
      @hidden
    end

    def min=(min : Int32)
      @min = min
    end

    def min : Int32
      @min
    end

    def clean
      @info = ""
      @current_row = 0
      @current_col = 0
      @top_row = 0
    end

    def background=(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
      if fw = @field_win
        LibNCurses.wbkgd(fw, attrib.to_u32)
      end
      if lw = @label_win
        LibNCurses.wbkgd(lw, attrib.to_u32)
      end
    end

    def focus
      LibNCurses.curs_set(2)
      if fw = @field_win
        fw.move(@current_row, @current_col)
        CRT::Screen.wrefresh(fw)
      end
    end

    def unfocus
      LibNCurses.curs_set(0)
      if fw = @field_win
        CRT::Screen.wrefresh(fw)
      end
    end

    def object_type : Symbol
      :MULTI_ENTRY
    end
  end
end
