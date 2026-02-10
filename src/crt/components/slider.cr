module CRT
  class Slider(T) < CRT::CRTObjs
    getter current : T

    def current=(value : T)
      @current = value
      limit_current_value
    end

    property low : T
    property high : T
    property inc : T
    property fastinc : T
    property filler : Int32 = 0
    property field_width : Int32 = 0
    property digits : Int32 = 0
    property parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @return_data : T

    def initialize(cdkscreen : CRT::Screen, *,
                   low : T, high : T, inc : T, fast_inc : T,
                   x : Int32, y : Int32,
                   title : String = "", label : String = "",
                   start : T = low,
                   filler : Int32 = '#'.ord | LibNCurses::Attribute::Reverse.value.to_i32,
                   field_width : Int32 = 0, digits : Int32 = 0,
                   box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)
      box_height = @border_size * 2 + 1

      @digits = digits
      @label = [] of Int32
      @label_len = 0
      @label_win = nil
      @current = start
      @low = low
      @high = high
      @inc = inc
      @fastinc = fast_inc
      @return_data = low

      high_value_len = format_value(high).size

      field_width = CRT.set_widget_dimension(parent_width, field_width, 0)

      # Translate the label string to a chtype array
      if !label.empty?
        label_len_arr = [0]
        @label = char2chtype(label, label_len_arr, [] of Int32)
        @label_len = label_len_arr[0]
        box_width = @label_len + field_width + high_value_len + 2 * @border_size
      else
        box_width = field_width + high_value_len + 2 * @border_size
      end

      old_width = box_width
      box_width = set_title(title, box_width)
      horizontal_adjust = (box_width - old_width) // 2

      box_height += @title_lines

      # Clamp to parent
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min
      field_width = {field_width, box_width - @label_len - high_value_len - 1}.min

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

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
      @field_win = CRT.subwin(w, 1, field_width + high_value_len - 1,
        ypos + @title_lines + @border_size,
        xpos + @label_len + horizontal_adjust + @border_size)
      if fw = @field_win
        fw.keypad(true)
      end

      @screen = cdkscreen
      @parent = parent_window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = field_width - 1
      @filler = filler
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      # Clamp start value
      @current = low if start < low

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      # Key bindings
      bind(:SLIDER, 'u'.ord, :getc, LibNCurses::Key::Up.value)
      bind(:SLIDER, 'U'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(:SLIDER, CRT::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)
      bind(:SLIDER, CRT::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(:SLIDER, 'g'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SLIDER, '^'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SLIDER, 'G'.ord, :getc, LibNCurses::Key::End.value)
      bind(:SLIDER, '$'.ord, :getc, LibNCurses::Key::End.value)

      cdkscreen.register(:SLIDER, self)
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

      case input
      when LibNCurses::Key::Down.value
        @current -= @inc
      when LibNCurses::Key::Up.value
        @current += @inc
      when LibNCurses::Key::Right.value
        @current += @inc
      when LibNCurses::Key::Left.value
        @current -= @inc
      when LibNCurses::Key::PageUp.value
        @current += @fastinc
      when LibNCurses::Key::PageDown.value
        @current -= @fastinc
      when LibNCurses::Key::Home.value
        @current = @low
      when LibNCurses::Key::End.value
        @current = @high
      when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        set_exit_type(input)
        ret = @current
        @complete = true
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        case input
        when 'd'.ord, '-'.ord
          @current -= @inc
        when '+'.ord
          @current += @inc
        when 'D'.ord
          @current -= @fastinc
        when '0'.ord
          @current = @low
        else
          CRT.beep
        end
      end

      limit_current_value

      unless @complete
        draw_field
        set_exit_type(0)
      end

      @return_data = ret
      ret
    end

    def draw(box : Bool)
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

      range = (@high - @low).to_f64
      step = range > 0 ? @field_width.to_f64 / range : 0.0
      filler_characters = ((@current - @low).to_f64 * step).to_i32

      fw.erase

      # Draw filler bar
      (0...filler_characters).each do |x|
        Draw.mvwaddch(fw, 0, x, @filler)
      end

      # Draw the value text
      temp = format_value(@current)
      Draw.write_char_attrib(fw, @field_width, 0, temp,
        0, CRT::HORIZONTAL, 0, temp.size)

      CRT::Screen.wrefresh(fw)
    end

    def erase
      CRT.erase_curses_window(@label_win)
      CRT.erase_curses_window(@field_win)
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CRT.delete_curses_window(@field_win)
      CRT.delete_curses_window(@label_win)
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clean_bindings(:SLIDER)
      CRT::Screen.unregister(:SLIDER, self)
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
      :SLIDER
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
