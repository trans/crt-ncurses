module CRT
  class Scale(T) < CRT::CRTObjs
    getter current : T

    def current=(value : T)
      @current = value
      limit_current_value
    end

    getter low : T
    getter high : T
    property step : T
    property page : T
    property field_attr : Int32 = 0
    getter field_width : Int32 = 0
    property digits : Int32 = 0
    getter parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : T

    def initialize(screen : CRT::Screen, *,
                   low : T, high : T, step : T, page : T,
                   x : Int32, y : Int32,
                   title : String = "", label : String = "",
                   start : T = low, field_attr : Int32 = 0,
                   field_width : Int32 = 0, digits : Int32 = 0,
                   box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)
      box_height = @border_size * 2 + 1

      @digits = digits
      @current = start
      @low = low
      @high = high
      @step = step
      @page = page
      @result_data = low

      field_width = CRT.set_widget_dimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Translate label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        @label, @label_len, _ = char2chtype(label)
        box_width = @label_len + field_width + 2
      end

      old_width = box_width
      box_width = set_title(title, box_width)
      horizontal_adjust = (box_width - old_width) // 2

      box_height += @title_lines

      # Clamp
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min
      field_width = {field_width, box_width - @label_len - 2 * @border_size}.min

      # Align
      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      # Create main window
      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Create label window
      if @label.size > 0
        @label_win = CRT.subwin(w, 1, @label_len,
          ypos + @title_lines + @border_size,
          xpos + horizontal_adjust + @border_size)
      end

      # Create field window
      @field_win = CRT.subwin(w, 1, field_width,
        ypos + @title_lines + @border_size,
        xpos + @label_len + horizontal_adjust + @border_size)
      if fw = @field_win
        fw.keypad(true)
      end

      @screen = screen
      @parent = parent_window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = field_width
      @field_attr = field_attr
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      # Key bindings
      remap_key('u'.ord, LibNCurses::Key::Up.value)
      remap_key('U'.ord, LibNCurses::Key::PageUp.value)
      remap_key(CRT::BACKCHAR, LibNCurses::Key::PageUp.value)
      remap_key(CRT::FORCHAR, LibNCurses::Key::PageDown.value)
      remap_key('g'.ord, LibNCurses::Key::Home.value)
      remap_key('^'.ord, LibNCurses::Key::Home.value)
      remap_key('G'.ord, LibNCurses::Key::End.value)
      remap_key('$'.ord, LibNCurses::Key::End.value)

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : T
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
      @low
    end

    def limit_current_value
      if @current < @low
        @current = @low
        CRT.beep
      elsif @current > @high
        @current = @high
        CRT.beep
      end
    end

    def inject(input : Int32) : T
      ret = @low
      @complete = false

      set_exit_type(0)
      draw_field

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
        when LibNCurses::Key::Down.value
          @current -= @step
        when LibNCurses::Key::Up.value
          @current += @step
        when LibNCurses::Key::PageUp.value
          @current += @page
        when LibNCurses::Key::PageDown.value
          @current -= @page
        when LibNCurses::Key::Home.value
          @current = @low
        when LibNCurses::Key::End.value
          @current = @high
        when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
          set_exit_type(resolved)
          ret = @current
          @complete = true
        when CRT::KEY_ESC
          set_exit_type(resolved)
          @complete = true
        when CRT::REFRESH
          if scr = @screen
            scr.erase
            scr.refresh
          end
        else
          case resolved
          when 'd'.ord, '-'.ord
            @current -= @step
          when '+'.ord
            @current += @step
          when 'D'.ord
            @current -= @page
          when '0'.ord
            @current = @low
          else
            CRT.beep
          end
        end
      end

      limit_current_value

      unless @complete
        draw_field
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)

        if lw = @label_win
          Draw.write_chtype(lw, 0, 0, @label, CRT::HORIZONTAL, 0, @label_len)
          CRT::Screen.wrefresh(lw)
        end

        wrefresh
      end

      draw_field
    end

    def draw_field
      return unless fw = @field_win
      fw.erase

      temp = format_value(@current)
      Draw.write_char_attrib(fw,
        @field_width - temp.size - 1, 0, temp, @field_attr,
        CRT::HORIZONTAL, 0, temp.size)

      CRT::Screen.wrefresh(fw)
    end

    def erase
      CRT.erase_curses_window(@label_win)
      CRT.erase_curses_window(@field_win)
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

    def set_range(low : T, high : T)
      if low <= high
        @low = low
        @high = high
      else
        @low = high
        @high = low
      end
      limit_current_value
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
      draw(@box)
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :SCALE
    end

    private def format_value(value : T) : String
      if @digits > 0
        "%.#{@digits}f" % value.to_f64
      else
        value.to_s
      end
    end
  end
end
