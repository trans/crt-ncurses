module CRT
  class Entry < CRT::CRTObjs
    property info : String = ""
    property left_char : Int32 = 0
    property screen_col : Int32 = 0
    getter field_width : Int32 = 0
    property min : Int32 = 0
    property max : Int32 = 0
    getter field_attr : Int32 = 0
    property filler : Char = ' '
    property hidden : Char = ' '
    property disp_type : CRT::DisplayType = CRT::DisplayType::MIXED
    getter parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : String | Int32 = 0
    @callbackfn : Proc(CRT::Entry, Int32, Nil)? = nil

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   field_width : Int32, title : String = "", label : String = "",
                   field_attr : Int32 = 0, filler : Char = ' ',
                   disp_type : CRT::DisplayType = CRT::DisplayType::MIXED,
                   min : Int32 = 0, max : Int32 = 512,
                   box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = 0

      set_box(box)
      box_height = @border_size * 2 + 1

      field_width = CRT.set_widget_dimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Translate the label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        label_len_arr = [0]
        @label = char2chtype(label, label_len_arr, [] of Int32)
        @label_len = label_len_arr[0]
        box_width += @label_len
      end

      old_width = box_width
      box_width = set_title(title, box_width)
      horizontal_adjust = (box_width - old_width) // 2

      box_height += @title_lines

      # Clamp dimensions
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min
      field_width = {field_width, box_width - @label_len - 2 * @border_size}.min

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the main window
      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Create the field window (subwindow)
      @field_win = CRT.subwin(w,
        1, field_width,
        ypos + @title_lines + @border_size,
        xpos + @label_len + horizontal_adjust + @border_size
      )
      if fw = @field_win
        fw.keypad(true)
      end

      # Create label window if needed
      if !label.empty?
        @label_win = CRT.subwin(w,
          1, @label_len,
          ypos + @title_lines + @border_size,
          xpos + horizontal_adjust + @border_size
        )
      end

      @info = ""
      @screen = screen
      @parent = parent_window
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @filler = filler
      @hidden = filler
      @input_window = @field_win
      @accepts_focus = true
      @shadow = shadow
      @screen_col = 0
      @left_char = 0
      @min = min
      @max = max
      @box_width = box_width
      @box_height = box_height
      @disp_type = disp_type

      @callbackfn = ->(entry : CRT::Entry, character : Int32) do
        plainchar = CRT::Display.filter_by_display_type(entry.disp_type, character)

        if plainchar == -1 || entry.info.size >= entry.max
          CRT.beep
        else
          if entry.screen_col != entry.field_width - 1
            cursor_pos = entry.screen_col + entry.left_char
            front = entry.info[0...cursor_pos]? || ""
            back = entry.info[cursor_pos..]? || ""
            entry.info = front + plainchar.chr + back
            entry.screen_col += 1
          else
            entry.info += plainchar.chr.to_s
            if entry.info.size < entry.max
              entry.left_char += 1
            end
          end
          entry.draw_field
        end
        nil
      end

      # Shadow window
      if shadow
        @shadow_win = NCurses::Window.new(
          height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : String | Int32
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

      if @exit_type == CRT::ExitType::NORMAL
        @info
      else
        0
      end
    end

    def move_to_end
      if @info.size >= @field_width
        if @info.size < @max
          char_count = @field_width - 1
          @left_char = @info.size - char_count
          @screen_col = char_count
        else
          @left_char = @info.size - @field_width
          @screen_col = @info.size - 1
        end
      else
        @left_char = 0
        @screen_col = @info.size
      end
    end

    def inject(input : Int32) : String | Int32
      ret : String | Int32 = 1
      @complete = false

      set_exit_type(0)
      draw_field

      curr_pos = @screen_col + @left_char

      case input
      when LibNCurses::Key::Up.value, LibNCurses::Key::Down.value
        CRT.beep
      when LibNCurses::Key::Home.value
        @left_char = 0
        @screen_col = 0
        draw_field
      when CRT::TRANSPOSE
        if curr_pos >= @info.size - 1
          CRT.beep
        else
          # Swap characters
          chars = @info.chars
          chars[curr_pos], chars[curr_pos + 1] = chars[curr_pos + 1], chars[curr_pos]
          @info = chars.join
          draw_field
        end
      when LibNCurses::Key::End.value
        move_to_end
        draw_field
      when LibNCurses::Key::Left.value
        if curr_pos <= 0
          CRT.beep
        elsif @screen_col == 0
          @left_char -= 1
          draw_field
        else
          @screen_col -= 1
          if fw = @field_win
            fw.move(0, @screen_col)
          end
        end
      when LibNCurses::Key::Right.value
        if curr_pos >= @info.size
          CRT.beep
        elsif @screen_col == @field_width - 1
          @left_char += 1
          draw_field
        else
          @screen_col += 1
          if fw = @field_win
            fw.move(0, @screen_col)
          end
        end
      when LibNCurses::Key::Backspace.value, LibNCurses::Key::Delete.value
        if @disp_type.viewonly?
          CRT.beep
        else
          success = false
          delete_pos = curr_pos
          delete_pos -= 1 if input == LibNCurses::Key::Backspace.value

          if delete_pos >= 0 && @info.size > 0
            if delete_pos < @info.size
              @info = @info[0...delete_pos] + (@info[(delete_pos + 1)..]? || "")
              success = true
            elsif input == LibNCurses::Key::Backspace.value
              @info = @info[0...-1]
              success = true
            end
          end

          if success
            if input == LibNCurses::Key::Backspace.value
              if @screen_col > 0
                @screen_col -= 1
              else
                @left_char -= 1
              end
            end
            draw_field
          else
            CRT.beep
          end
        end
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::ERASE
        if @info.size != 0
          clean
          draw_field
        end
      when CRT::CUT
        if @info.size != 0
          CRT::CRTObjs.paste_buffer = @info.dup
          clean
          draw_field
        else
          CRT.beep
        end
      when CRT::COPY
        if @info.size != 0
          CRT::CRTObjs.paste_buffer = @info.dup
        else
          CRT.beep
        end
      when CRT::PASTE
        if !CRT::CRTObjs.paste_buffer.empty?
          self.value = CRT::CRTObjs.paste_buffer
          draw_field
        else
          CRT.beep
        end
      when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        if @info.size >= @min
          set_exit_type(input)
          ret = @info
          @complete = true
        else
          CRT.beep
        end
      when CRT::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        if cb = @callbackfn
          cb.call(self, input)
        end
      end

      unless @complete
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def clean
      @info = ""
      if fw = @field_win
        LibNCurses.wmove(fw, 0, 0)
        LibNCurses.whline(fw, @filler.ord.to_i8, @field_width)
      end
      @screen_col = 0
      @left_char = 0
      wrefresh(@field_win)
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)
        wrefresh
      end

      # Draw the label
      if lw = @label_win
        Draw.write_chtype(lw, 0, 0, @label, CRT::HORIZONTAL, 0, @label_len)
        CRT::Screen.wrefresh(lw)
      end

      draw_field
    end

    def draw_field
      return unless fw = @field_win

      # Draw filler characters
      LibNCurses.wmove(fw, 0, 0)
      LibNCurses.whline(fw, @filler.ord.to_i8, @field_width)

      # Draw the info if present
      if @info.size > 0
        if CRT::Display.hidden_display_type?(@disp_type)
          (@left_char...@info.size).each do |x|
            LibNCurses.mvwaddch(fw, 0, x - @left_char, @hidden.ord.to_i8)
          end
        else
          (@left_char...@info.size).each do |x|
            break if x - @left_char >= @field_width
            ch = @info[x].ord
            attr = LibNCurses::Attribute.new((@field_attr & ~0xFF).to_u32)
            LibNCurses.wattron(fw, attr)
            LibNCurses.mvwaddch(fw, 0, x - @left_char, ch.to_i8)
            LibNCurses.wattroff(fw, attr)
          end
        end
        LibNCurses.wmove(fw, 0, @screen_col)
      end

      CRT::Screen.wrefresh(fw)
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

    def value=(new_value : String?)
      if new_value.nil?
        @info = ""
        @left_char = 0
        @screen_col = 0
      else
        @info = new_value.dup
        move_to_end
      end
    end

    def value : String
      @info
    end

    def max=(max : Int32)
      @max = max
    end

    def min=(min : Int32)
      @min = min
    end

    def filler_char=(filler_char : Char)
      @filler = filler_char
    end

    def hidden_char=(hidden_character : Char)
      @hidden = hidden_character
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

    def callback=(callback : Proc(CRT::Entry, Int32, Nil))
      @callbackfn = callback
    end

    def focus
      if fw = @field_win
        fw.move(0, @screen_col)
        CRT::Screen.wrefresh(fw)
      end
    end

    def unfocus
      draw(@box)
      if fw = @field_win
        CRT::Screen.wrefresh(fw)
      end
    end

    def object_type : Symbol
      :ENTRY
    end
  end
end
