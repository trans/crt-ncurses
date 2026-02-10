module CDK
  class Scale < CDK::CDKObjs
    property current : Int32 = 0
    property low : Int32 = 0
    property high : Int32 = 0
    property inc : Int32 = 1
    property fastinc : Int32 = 5
    property field_attr : Int32 = 0
    property field_width : Int32 = 0
    property parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1
    @field_edit : Int32 = 0

    def initialize(cdkscreen : CDK::Screen, xplace : Int32, yplace : Int32,
                   title : String, label : String, field_attr : Int32,
                   field_width : Int32, start : Int32, low : Int32, high : Int32,
                   inc : Int32, fast_inc : Int32, box : Bool, shadow : Bool)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)
      box_height = @border_size * 2 + 1

      field_width = CDK.set_widget_dimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Translate label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        label_len_arr = [0]
        @label = char2chtype(label, label_len_arr, [] of Int32)
        @label_len = label_len_arr[0]
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
        @label_win = CDK.subwin(w, 1, @label_len,
          ypos + @title_lines + @border_size,
          xpos + horizontal_adjust + @border_size)
      end

      # Create field window
      @field_win = CDK.subwin(w, 1, field_width,
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
      @field_width = field_width
      @field_attr = field_attr
      @current = start
      @low = low
      @high = high
      @inc = inc
      @fastinc = fast_inc
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @field_edit = 0

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      # Key bindings
      bind(:SCALE, 'u'.ord, :getc, LibNCurses::Key::Up.value)
      bind(:SCALE, 'U'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(:SCALE, CDK::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)
      bind(:SCALE, CDK::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(:SCALE, 'g'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SCALE, '^'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SCALE, 'G'.ord, :getc, LibNCurses::Key::End.value)
      bind(:SCALE, '$'.ord, :getc, LibNCurses::Key::End.value)

      cdkscreen.register(:SCALE, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      ret = -1
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          input = getch([] of Bool)
          ret = inject(input)
          return ret if @exit_type != CDK::ExitType::EARLY_EXIT
        end
      else
        actions.each do |action|
          ret = inject(action)
          return ret if @exit_type != CDK::ExitType::EARLY_EXIT
        end
      end

      set_exit_type(0)
      ret
    end

    def limit_current_value
      if @current < @low
        @current = @low
        CDK.beep
      elsif @current > @high
        @current = @high
        CDK.beep
      end
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw_field

      case input
      when LibNCurses::Key::Down.value
        @current -= @inc
      when LibNCurses::Key::Up.value
        @current += @inc
      when LibNCurses::Key::PageUp.value
        @current += @fastinc
      when LibNCurses::Key::PageDown.value
        @current -= @fastinc
      when LibNCurses::Key::Home.value
        @current = @low
      when LibNCurses::Key::End.value
        @current = @high
      when CDK::KEY_TAB, CDK::KEY_RETURN, LibNCurses::Key::Enter.value
        set_exit_type(input)
        ret = @current
        @complete = true
      when CDK::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CDK::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        # Command shortcuts when not in edit mode
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
          CDK.beep
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

    def draw(box : Bool)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)

        if lw = @label_win
          Draw.write_chtype(lw, 0, 0, @label, CDK::HORIZONTAL, 0, @label_len)
          CDK::Screen.wrefresh(lw)
        end

        wrefresh
      end

      draw_field
    end

    def draw_field
      return unless fw = @field_win
      fw.erase

      # Draw the value right-aligned in the field
      temp = @current.to_s
      Draw.write_char_attrib(fw,
        @field_width - temp.size - 1, 0, temp, @field_attr,
        CDK::HORIZONTAL, 0, temp.size)

      CDK::Screen.wrefresh(fw)
    end

    def erase
      CDK.erase_curses_window(@label_win)
      CDK.erase_curses_window(@field_win)
      CDK.erase_curses_window(@win)
      CDK.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CDK.delete_curses_window(@field_win)
      CDK.delete_curses_window(@label_win)
      CDK.delete_curses_window(@shadow_win)
      CDK.delete_curses_window(@win)
      clean_bindings(:SCALE)
      CDK::Screen.unregister(:SCALE, self)
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

    def object_type : Symbol
      :SCALE
    end
  end
end
