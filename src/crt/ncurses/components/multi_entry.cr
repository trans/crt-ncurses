module CRT::Ncurses
  class MultiEntry < CRT::Ncurses::CRTObjs
    property info : String = ""
    getter current_col : Int32 = 0
    getter current_row : Int32 = 0
    getter top_row : Int32 = 0
    property disp_type : CRT::Ncurses::DisplayType = CRT::Ncurses::DisplayType::MIXED
    getter field_width : Int32 = 0
    getter rows : Int32 = 0
    property newline_on_enter : Bool = false

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

    def initialize(screen : CRT::Ncurses::Screen, *, x : Int32, y : Int32,
                   field_width : Int32, field_rows : Int32, logical_rows : Int32,
                   title : String = "", label : String = "", field_attr : Int32 = 0,
                   filler : Char = ' ', disp_type : CRT::Ncurses::DisplayType = CRT::Ncurses::DisplayType::MIXED,
                   min : Int32 = 0, box : Bool | CRT::Ncurses::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)

      field_width = CRT::Ncurses.set_widget_dimension(parent_width, field_width, 0)
      field_rows = CRT::Ncurses.set_widget_dimension(parent_height, field_rows, 0)
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
        @label_win = CRT::Ncurses.subwin(w, field_rows, @label_len + 2 * @border_size,
          ypos + @title_lines + @border_size, xpos + horizontal_adjust + @border_size)
      end

      # Field window
      @field_win = CRT::Ncurses.subwin(w, field_rows, field_width,
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
            return ret if @exit_type != CRT::Ncurses::ExitType::EARLY_EXIT
          end
        else
          actions.each do |action|
            ret = inject(action)
            return ret if @exit_type != CRT::Ncurses::ExitType::EARLY_EXIT
          end
        end

        set_exit_type(0)
        ""
      ensure
        LibNCurses.curs_set(0)
      end
    end

    def cursor_pos : Int32
      visual_to_pos(@top_row + @current_row, @current_col)
    end

    # Convert visual (row, col) to string index, accounting for newlines.
    private def visual_to_pos(target_row : Int32, target_col : Int32) : Int32
      row = 0
      col = 0
      @info.each_char_with_index do |ch, i|
        return i if row == target_row && col == target_col
        if ch == '\n'
          return i if row == target_row # past end of short line
          row += 1
          col = 0
        else
          col += 1
          if col >= @field_width
            col = 0
            row += 1
          end
        end
      end
      @info.size
    end

    # Convert string index to visual (row, col).
    private def pos_to_visual(target_pos : Int32) : {Int32, Int32}
      row = 0
      col = 0
      @info.each_char_with_index do |ch, i|
        return {row, col} if i == target_pos
        if ch == '\n'
          row += 1
          col = 0
        else
          col += 1
          if col >= @field_width
            col = 0
            row += 1
          end
        end
      end
      {row, col}
    end

    # Length of a visual row (chars before newline or field_width wrap).
    private def visual_line_length(target_row : Int32) : Int32
      row = 0
      col = 0
      @info.each_char do |ch|
        if ch == '\n'
          return col if row == target_row
          row += 1
          col = 0
        else
          col += 1
          if col >= @field_width
            return @field_width if row == target_row
            col = 0
            row += 1
          end
        end
      end
      return col if row == target_row
      0
    end

    # Total number of visual rows in the current content.
    private def total_visual_rows : Int32
      row = 0
      col = 0
      @info.each_char do |ch|
        if ch == '\n'
          row += 1
          col = 0
        else
          col += 1
          if col >= @field_width
            col = 0
            row += 1
          end
        end
      end
      row + 1
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
          prev_len = visual_line_length(@top_row - 1)
          moved = set_cur_pos(@current_row, {prev_len, @field_width - 1}.min)
          redraw = set_top_row(@top_row - 1)
        end
      else
        prev_len = visual_line_length(@top_row + @current_row - 1)
        moved = set_cur_pos(@current_row - 1, {prev_len, @field_width - 1}.min)
      end

      if !moved && !redraw
        CRT::Ncurses.beep
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
        end_row, end_col = pos_to_visual(@info.size)
        if end_row < @rows
          redraw = set_top_row(0)
          moved = set_cur_pos(end_row, end_col)
        else
          redraw = set_top_row(end_row - @rows + 1)
          moved = set_cur_pos(@rows - 1, end_col)
        end
      when LibNCurses::Key::Left.value
        _, moved, redraw = handle_key_left(moved, redraw)
      when LibNCurses::Key::Right.value
        cp = cursor_pos
        if cp >= @info.size
          CRT::Ncurses.beep
        elsif @info[cp] == '\n' || @current_col >= @field_width - 1
          # At newline or end of wrapped line — advance to next row
          if @current_row < @rows - 1
            moved = set_cur_pos(@current_row + 1, 0)
          elsif @top_row + @current_row + 1 < total_visual_rows
            moved = set_cur_pos(@current_row, 0)
            redraw = set_top_row(@top_row + 1)
          else
            CRT::Ncurses.beep
          end
        else
          moved = set_cur_pos(@current_row, @current_col + 1)
        end
      when LibNCurses::Key::Down.value
        next_abs_row = @top_row + @current_row + 1
        if next_abs_row < total_visual_rows
          target_col = {@current_col, visual_line_length(next_abs_row)}.min
          if @current_row < @rows - 1
            moved = set_cur_pos(@current_row + 1, target_col)
          else
            redraw = set_top_row(@top_row + 1)
            @current_col = target_col
          end
        else
          CRT::Ncurses.beep
        end
      when LibNCurses::Key::Up.value
        prev_abs_row = @top_row + @current_row - 1
        if prev_abs_row >= 0
          target_col = {@current_col, visual_line_length(prev_abs_row)}.min
          if @current_row > 0
            moved = set_cur_pos(@current_row - 1, target_col)
          else
            redraw = set_top_row(@top_row - 1)
            @current_col = target_col
          end
        else
          CRT::Ncurses.beep
        end
      when LibNCurses::Key::Backspace.value, CRT::Ncurses::DELETE
        if @disp_type == CRT::Ncurses::DisplayType::VIEWONLY
          CRT::Ncurses.beep
        elsif @info.size == 0
          CRT::Ncurses.beep
        elsif input == CRT::Ncurses::DELETE
          # Delete char at cursor
          cp = cursor_pos
          if cp < @info.size
            @info = @info[0...cp] + @info[cp + 1..]
            draw_field
          else
            CRT::Ncurses.beep
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
              CRT::Ncurses.beep
            end
          end
        end
      when CRT::Ncurses::TRANSPOSE
        cp = cursor_pos
        if cp >= @info.size - 1
          CRT::Ncurses.beep
        else
          chars = @info.chars
          chars[cp], chars[cp + 1] = chars[cp + 1], chars[cp]
          @info = chars.join
          draw_field
        end
      when CRT::Ncurses::ERASE
        if @info.size != 0
          clean
          draw_field
        end
      when CRT::Ncurses::CUT
        if @info.size == 0
          CRT::Ncurses.beep
        else
          CRT::Ncurses::CRTObjs.paste_buffer = @info.clone
          clean
          draw_field
        end
      when CRT::Ncurses::COPY
        if @info.size == 0
          CRT::Ncurses.beep
        else
          CRT::Ncurses::CRTObjs.paste_buffer = @info.clone
        end
      when CRT::Ncurses::PASTE
        if CRT::Ncurses::CRTObjs.paste_buffer.size == 0
          CRT::Ncurses.beep
        else
          self.value = CRT::Ncurses::CRTObjs.paste_buffer
          draw(@box)
        end
      when CRT::Ncurses::KEY_TAB, CRT::Ncurses::KEY_RETURN, LibNCurses::Key::Enter.value
        if @newline_on_enter && input != CRT::Ncurses::KEY_TAB
          # Insert newline character
          if @info.size >= @total_width
            CRT::Ncurses.beep
          else
            cp = cursor_pos
            @info = @info[0...cp] + "\n" + @info[cp..]
            @current_col = 0
            @current_row += 1
            if @current_row >= @rows
              @current_row = @rows - 1
              @top_row += 1
            end
            draw_field
          end
        elsif @info.size < @min + 1
          CRT::Ncurses.beep
        else
          set_exit_type(input)
          @complete = true
          return @info
        end
      when CRT::Ncurses::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::Ncurses::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        if @disp_type == CRT::Ncurses::DisplayType::VIEWONLY || @info.size >= @total_width
          CRT::Ncurses.beep
        else
          # Filter character and insert
          newchar = Display.filter_by_display_type(@disp_type, input)
          if newchar == -1
            CRT::Ncurses.beep
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
          CRT::Ncurses::Screen.wrefresh(fw)
        end
      end

      unless @complete
        set_exit_type(0)
        LibNCurses.curs_set(2)
      end

      @result_data = @info
      @info
    end

    def draw_field
      return unless fw = @field_win

      # Find the string position for the start of @top_row
      start_pos = visual_to_pos(@top_row, 0)

      if w = @win
        draw_title(w)
        wrefresh
      end

      pos = start_pos

      @rows.times do |x|
        y = 0
        while y < @field_width
          if pos < @info.size
            ch = @info[pos]
            if ch == '\n'
              # Fill rest of row with filler
              while y < @field_width
                Draw.mvwaddch(fw, x, y, @filler)
                y += 1
              end
              pos += 1
              break
            elsif Display.hidden_display_type?(@disp_type)
              Draw.mvwaddch(fw, x, y, @filler)
              pos += 1
            else
              Draw.mvwaddch(fw, x, y, ch.ord | @field_attr)
              pos += 1
            end
          else
            Draw.mvwaddch(fw, x, y, @filler)
          end
          y += 1
        end
      end

      fw.move(@current_row, @current_col)
      CRT::Ncurses::Screen.wrefresh(fw)
    end

    def draw(box : Bool = @box)
      if w = @win
        Draw.draw_obj_box(w, self) if box
        wrefresh
      end

      Draw.draw_shadow(@shadow_win)

      if lw = @label_win
        Draw.write_chtype(lw, 0, 0, @label, CRT::Ncurses::HORIZONTAL, 0, @label_len)
        CRT::Ncurses::Screen.wrefresh(lw)
      end

      draw_field
    end

    def erase
      CRT::Ncurses.erase_curses_window(@field_win)
      CRT::Ncurses.erase_curses_window(@label_win)
      CRT::Ncurses.erase_curses_window(@win)
      CRT::Ncurses.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
      clean_title
      CRT::Ncurses.delete_curses_window(@field_win)
      CRT::Ncurses.delete_curses_window(@label_win)
      CRT::Ncurses.delete_curses_window(@shadow_win)
      CRT::Ncurses.delete_curses_window(@win)
      clear_key_bindings
      CRT::Ncurses::Screen.unregister(object_type, self)
    end

    def value=(new_value : String)
      @info = new_value
      end_row, end_col = pos_to_visual(new_value.size)
      if end_row < @rows
        @top_row = 0
        @current_row = end_row
        @current_col = end_col
      else
        @top_row = end_row - @rows + 1
        @current_row = @rows - 1
        @current_col = end_col
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
      if fw = @field_win
        fw.move(@current_row, @current_col)
        CRT::Ncurses::Screen.wrefresh(fw)
      end
      LibNCurses.curs_set(2)
    end

    def unfocus
      LibNCurses.curs_set(0)
      if fw = @field_win
        CRT::Ncurses::Screen.wrefresh(fw)
      end
    end

    def object_type : Symbol
      :MULTI_ENTRY
    end
  end
end
