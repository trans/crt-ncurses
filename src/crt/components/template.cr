module CRT
  class Template < CRT::CRTObjs
    property plate : String = ""
    property info : String = ""
    getter plate_pos : Int32 = 0
    getter screen_pos : Int32 = 0
    getter info_pos : Int32 = 0
    property min : Int32 = 0
    getter field_width : Int32 = 0
    getter parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @overlay : Array(Int32) = [] of Int32
    @overlay_len : Int32 = 0
    @field_attr : Int32 = 0
    @plate_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @return_data : String = ""

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   plate : String, overlay : String, title : String = "",
                   label : String = "", box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      return if plate.empty?

      set_box(box)

      field_width = plate.size + 2 * @border_size

      # Translate label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        label_len_arr = [0]
        @label = char2chtype(label, label_len_arr, [] of Int32)
        @label_len = label_len_arr[0]
      end

      # Translate overlay
      if !overlay.empty?
        overlay_len_arr = [0]
        @overlay = char2chtype(overlay, overlay_len_arr, [] of Int32)
        @overlay_len = overlay_len_arr[0]
        @field_attr = @overlay.size > 0 ? (@overlay[0] & ~0xFF) : 0
      else
        @overlay = [] of Int32
        @overlay_len = 0
        @field_attr = 0
      end

      box_width = field_width + @label_len + 2 * @border_size

      old_width = box_width
      box_width = set_title(title, box_width)
      horizontal_adjust = (box_width - old_width) // 2

      box_height = box ? 3 : 1
      box_height += @title_lines

      # Clamp
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min
      field_width = {field_width, box_width - @label_len - 2 * @border_size}.min

      # Align
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Label window
      if @label.size > 0
        @label_win = CRT.subwin(w, 1, @label_len,
          ypos + @title_lines + @border_size,
          xpos + horizontal_adjust + @border_size)
      end

      # Field window
      @field_win = CRT.subwin(w, 1, field_width,
        ypos + @title_lines + @border_size,
        xpos + @label_len + horizontal_adjust + @border_size)
      if fw = @field_win
        fw.keypad(true)
      end

      @plate_len = plate.size
      @info = ""
      @plate = plate

      @screen = screen
      @parent = parent_window
      @shadow_win = nil
      @field_width = field_width
      @box_height = box_height
      @box_width = box_width
      @plate_pos = 0
      @screen_pos = 0
      @info_pos = 0
      @min = 0
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def self.is_plate_char?(c : Char) : Bool
      "#ACcMXz".includes?(c)
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

    def inject(input : Int32) : String
      @complete = false

      set_exit_type(0)
      draw_field

      case input
      when CRT::ERASE
        if @info.size > 0
          clean
          draw_field
        end
      when CRT::CUT
        if @info.size > 0
          CRT::CRTObjs.paste_buffer = @info.clone
          clean
          draw_field
        else
          CRT.beep
        end
      when CRT::COPY
        if @info.size > 0
          CRT::CRTObjs.paste_buffer = @info.clone
        else
          CRT.beep
        end
      when CRT::PASTE
        if CRT::CRTObjs.paste_buffer.size > 0
          clean
          CRT::CRTObjs.paste_buffer.each_char do |ch|
            handle_input(ch.ord)
          end
          draw_field
        else
          CRT.beep
        end
      when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        if @info.size < @min
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
        handle_input(input)
      end

      unless @complete
        set_exit_type(0)
      end

      @return_data = @info
      @info
    end

    def handle_input(input : Int32)
      failed = false
      change = false
      moveby = false
      amount = 0
      mark = @info_pos

      if input == LibNCurses::Key::Left.value
        if mark != 0
          moveby = true
          amount = -1
        else
          failed = true
        end
      elsif input == LibNCurses::Key::Right.value
        if mark < @info.size
          moveby = true
          amount = 1
        else
          failed = true
        end
      else
        test = @info.clone

        if input == LibNCurses::Key::Backspace.value || input == CRT::DELETE
          if input == CRT::DELETE
            # Backspace behavior
            if mark != 0
              front = mark - 1 > 0 ? @info[0...mark - 1] : ""
              back = mark < @info.size ? @info[mark..] : ""
              test = front + back
              change = true
              amount = -1
            else
              failed = true
            end
          else
            # Delete key at cursor
            if mark < @info.size
              front = mark > 0 ? @info[0...mark] : ""
              back = mark + 1 < @info.size ? @info[mark + 1..] : ""
              test = front + back
              change = true
              amount = 0
            else
              failed = true
            end
          end
        elsif CRT.is_char?(input) && @plate_pos < @plate.size
          # Insert character
          if mark < test.size
            chars = test.chars
            chars.insert(mark, input.chr)
            test = chars.join
          else
            test += input.chr.to_s
          end
          change = true
          amount = 1
        else
          failed = true
        end

        if change
          if valid_template?(test)
            @info = test
            draw_field
          else
            failed = true
          end
        end
      end

      if failed
        CRT.beep
      elsif change || moveby
        @info_pos += amount
        @plate_pos += amount
        @screen_pos += amount
        adjust_cursor(amount)
      end
    end

    def valid_template?(input : String) : Bool
      pp = 0
      ip = 0
      chars = input.chars

      while ip < chars.size && pp < @plate.size
        newchar = chars[ip]
        while pp < @plate.size && !Template.is_plate_char?(@plate[pp])
          pp += 1
        end
        return false if pp == @plate.size

        # Check if input matches plate
        plate_ch = @plate[pp]
        if newchar.ascii_number? && "ACc".includes?(plate_ch)
          return false
        end
        if !newchar.ascii_number? && plate_ch == '#'
          return false
        end

        # Case conversion
        if plate_ch == 'C' || plate_ch == 'X'
          chars[ip] = newchar.upcase
        elsif plate_ch == 'c' || plate_ch == 'x'
          chars[ip] = newchar.downcase
        end

        ip += 1
        pp += 1
      end
      true
    end

    def mix : String
      mixed = String::Builder.new
      plate_pos = 0
      info_pos = 0

      if @info.size > 0
        while plate_pos < @plate_len && info_pos < @info.size
          if Template.is_plate_char?(@plate[plate_pos])
            mixed << @info[info_pos]
            info_pos += 1
          else
            mixed << @plate[plate_pos]
          end
          plate_pos += 1
        end
      end

      mixed.to_s
    end

    def unmix(info : String) : String
      unmixed = String::Builder.new
      pos = 0

      while pos < info.size && pos < @plate.size
        if Template.is_plate_char?(@plate[pos])
          unmixed << info[pos]
        end
        pos += 1
      end

      unmixed.to_s
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)
        wrefresh
      end

      draw_field
    end

    def draw_field
      return unless fw = @field_win

      # Draw label
      if lw = @label_win
        Draw.write_chtype(lw, 0, 0, @label, CRT::HORIZONTAL, 0, @label_len)
        CRT::Screen.wrefresh(lw)
      end

      # Draw overlay template
      if @overlay.size > 0
        Draw.write_chtype(fw, 0, 0, @overlay, CRT::HORIZONTAL, 0, @overlay_len)
      end

      # Draw info characters over plate positions
      if @info.size > 0
        pos = 0
        limit = {@field_width, @plate.size}.min
        limit.times do |x|
          if Template.is_plate_char?(@plate[x]) && pos < @info.size
            field_color = x < @overlay.size ? (@overlay[x] & ~0xFF) : 0
            Draw.mvwaddch(fw, 0, x, @info[pos].ord | field_color)
            pos += 1
          end
        end
        fw.move(0, @screen_pos)
      else
        adjust_cursor(1)
      end

      CRT::Screen.wrefresh(fw)
    end

    def adjust_cursor(direction : Int32)
      return unless fw = @field_win
      limit = {@field_width, @plate.size}.min
      while @plate_pos < limit && !Template.is_plate_char?(@plate[@plate_pos])
        @plate_pos += direction
        @screen_pos += direction
      end
      fw.move(0, @screen_pos)
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

    def value=(new_value : String)
      clean
      new_value.each_char do |ch|
        handle_input(ch.ord)
      end
    end

    def value : String
      @info
    end

    def min=(min : Int32)
      @min = min if min >= 0
    end

    def min : Int32
      @min
    end

    def clean
      @info = ""
      @screen_pos = 0
      @info_pos = 0
      @plate_pos = 0
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
      draw(@box)
    end

    def unfocus
      LibNCurses.curs_set(0)
      draw(@box)
    end

    def object_type : Symbol
      :TEMPLATE
    end
  end
end
