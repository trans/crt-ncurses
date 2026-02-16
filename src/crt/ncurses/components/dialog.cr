module CRT::Ncurses
  class Dialog < CRT::Ncurses::CRTObjs
    getter current_button : Int32 = 0

    MIN_DIALOG_WIDTH = 10

    getter message_rows : Int32 = 0
    getter button_count : Int32 = 0
    property highlight : Int32 = 0
    property separator : Bool = false
    getter parent : NCurses::Window? = nil

    @info : Array(Array(Int32)) = [] of Array(Int32)
    @info_len : Array(Int32) = [] of Int32
    @info_pos : Array(Int32) = [] of Int32
    @button_label : Array(Array(Int32)) = [] of Array(Int32)
    @button_len : Array(Int32) = [] of Int32
    @button_pos : Array(Int32) = [] of Int32
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1

    def initialize(screen : CRT::Ncurses::Screen, *, x : Int32, y : Int32,
                   mesg : Array(String), buttons : Array(String),
                   highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   separator : Bool = true, box : Bool | CRT::Ncurses::Framing | Nil = nil, shadow : Bool = false)
      super()
      box_width = MIN_DIALOG_WIDTH
      max_message_width = -1
      button_width = 0

      return if mesg.empty? || buttons.empty?

      set_box(box)
      box_height = separator ? 1 : 0
      box_height += mesg.size + 2 * @border_size + 1

      # Translate message strings to chtype arrays
      mesg.size.times do |x|
        chtype, len, pos = char2chtype(mesg[x])
        @info << chtype
        @info_len << len
        @info_pos << pos
        max_message_width = {max_message_width, len}.max
      end

      # Translate button labels to chtype arrays
      buttons.size.times do |x|
        chtype, len, _ = char2chtype(buttons[x])
        @button_label << chtype
        @button_len << len
        button_width += len + 1
      end
      button_width -= 1

      # Determine final box dimensions
      box_width = {box_width, max_message_width, button_width}.max
      box_width = box_width + 2 + 2 * @border_size

      parent_window = screen.window.not_nil!

      # Adjust positions
      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      @screen = screen
      @parent = parent_window
      @win = NCurses::Window.new(height: box_height, width: box_width,
        y: ypos, x: xpos)
      @shadow_win = nil
      @button_count = buttons.size
      @current_button = 0
      @message_rows = mesg.size
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @separator = separator
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      if w = @win
        w.keypad(true)
      end

      # Find button positions (centered)
      buttonadj = (box_width - button_width) // 2
      buttons.size.times do |x|
        @button_pos << buttonadj
        buttonadj = buttonadj + @button_len[x] + @border_size
      end

      # Create string alignments
      mesg.size.times do |x|
        @info_pos[x] = justify_string(box_width - 2 * @border_size,
          @info_len[x], @info_pos[x])
      end

      # Shadow window
      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)

      # Highlight the current button
      if w = @win
        Draw.write_chtype_attrib(w, @button_pos[@current_button],
          @box_height - 1 - @border_size, @button_label[@current_button],
          @highlight, CRT::Ncurses::HORIZONTAL, 0, @button_len[@current_button])
        wrefresh
      end

      if actions.nil? || actions.empty?
        loop do
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
      -1
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)

      case input
      when LibNCurses::Key::Left.value, LibNCurses::Key::ShiftTab.value, LibNCurses::Key::Backspace.value
        @current_button = @current_button == 0 ? @button_count - 1 : @current_button - 1
      when LibNCurses::Key::Right.value, CRT::Ncurses::KEY_TAB, ' '.ord
        @current_button = @current_button == @button_count - 1 ? 0 : @current_button + 1
      when LibNCurses::Key::Up.value, LibNCurses::Key::Down.value
        CRT::Ncurses.beep
      when CRT::Ncurses::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      when CRT::Ncurses::KEY_ESC
        set_exit_type(input)
        @complete = true
      when LibNCurses::Key::Enter.value, CRT::Ncurses::KEY_RETURN
        set_exit_type(input)
        ret = @current_button
        @complete = true
      end

      unless @complete
        draw_buttons
        wrefresh
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box

        # Draw the message
        @message_rows.times do |x|
          Draw.write_chtype(w,
            @info_pos[x] + @border_size, x + @border_size, @info[x],
            CRT::Ncurses::HORIZONTAL, 0, @info_len[x])
        end

        draw_buttons
        wrefresh
      end
    end

    def draw_buttons
      return unless w = @win

      @button_count.times do |x|
        Draw.write_chtype(w, @button_pos[x],
          @box_height - 1 - @border_size,
          @button_label[x], CRT::Ncurses::HORIZONTAL, 0,
          @button_len[x])
      end

      # Draw the separator line
      if @separator
        (1...@box_width).each do |x|
          Draw.mvwaddch(w, @box_height - 2 - @border_size, x,
            Draw::ACS_HLINE | @bx_attr)
        end
        Draw.mvwaddch(w, @box_height - 2 - @border_size, 0,
          'u'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 | @bx_attr) # ACS_LTEE
        Draw.mvwaddch(w, @box_height - 2 - @border_size, w.max_x - 1,
          't'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32 | @bx_attr) # ACS_RTEE
      end

      # Highlight the current button
      Draw.write_chtype_attrib(w, @button_pos[@current_button],
        @box_height - 1 - @border_size, @button_label[@current_button],
        @highlight, CRT::Ncurses::HORIZONTAL, 0, @button_len[@current_button])
    end

    def erase
      CRT::Ncurses.erase_curses_window(@win)
      CRT::Ncurses.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
      CRT::Ncurses.delete_curses_window(@win)
      CRT::Ncurses.delete_curses_window(@shadow_win)
      clear_key_bindings
      CRT::Ncurses::Screen.unregister(object_type, self)
    end

    def highlight=(highlight : Int32)
      @highlight = highlight
    end

    def separator=(separator : Bool)
      @separator = separator
    end

    def background=(attrib : Int32)
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
      :DIALOG
    end
  end
end
