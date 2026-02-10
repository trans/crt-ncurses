module CRT
  class Slider < CRT::CRTObjs
    property current : Int32 = 0
    property low : Int32 = 0
    property high : Int32 = 0
    property inc : Int32 = 1
    property fastinc : Int32 = 5
    property filler : Int32 = 0
    property field_width : Int32 = 0
    property parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @return_data : Int32 = -1
    @field_edit : Int32 = 0

    def initialize(cdkscreen : CRT::Screen, xplace : Int32, yplace : Int32,
                   title : String, label : String, filler : Int32,
                   field_width : Int32, start : Int32, low : Int32, high : Int32,
                   inc : Int32, fast_inc : Int32, box : Bool, shadow : Bool)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)
      box_height = @border_size * 2 + 1

      @label = [] of Int32
      @label_len = 0
      @label_win = nil
      high_value_len = formatted_size(high)

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
      xtmp = [xplace]
      ytmp = [yplace]
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
      @low = low
      @high = high
      @current = start
      @inc = inc
      @fastinc = fast_inc
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @field_edit = 0

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

    def limit_current_value
      if @current < @low
        @current = @low
        CRT.beep
      elsif @current > @high
        @current = @high
        CRT.beep
      end
    end

    def self.decrement(value : Int32, by : Int32) : Int32
      result = value - by
      result < value ? result : value
    end

    def self.increment(value : Int32, by : Int32) : Int32
      result = value + by
      result > value ? result : value
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw_field

      case input
      when LibNCurses::Key::Down.value
        @current = Slider.decrement(@current, @inc)
      when LibNCurses::Key::Up.value
        @current = Slider.increment(@current, @inc)
      when LibNCurses::Key::Right.value
        @current = Slider.increment(@current, @inc)
      when LibNCurses::Key::Left.value
        @current = Slider.decrement(@current, @inc)
      when LibNCurses::Key::PageUp.value
        @current = Slider.increment(@current, @fastinc)
      when LibNCurses::Key::PageDown.value
        @current = Slider.decrement(@current, @fastinc)
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
          @current = Slider.decrement(@current, @inc)
        when '+'.ord
          @current = Slider.increment(@current, @inc)
        when 'D'.ord
          @current = Slider.decrement(@current, @fastinc)
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

      range = @high - @low
      step = if range > 0
               1.0 * @field_width / range
             else
               0.0
             end

      filler_characters = ((@current - @low) * step).to_i32

      fw.erase

      # Draw filler bar
      (0...filler_characters).each do |x|
        Draw.mvwaddch(fw, 0, x, @filler)
      end

      # Draw the value text
      temp = @current.to_s
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

    def set_value(value : Int32)
      @current = value
      limit_current_value
    end

    def get_value : Int32
      @current
    end

    def set_low_high(low : Int32, high : Int32)
      if low <= high
        @low = low
        @high = high
      else
        @low = high
        @high = low
      end
      limit_current_value
    end

    def set_bk_attr(attrib : Int32)
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

    def formatted_size(value : Int32) : Int32
      value.to_s.size
    end

    def object_type : Symbol
      :SLIDER
    end
  end
end
